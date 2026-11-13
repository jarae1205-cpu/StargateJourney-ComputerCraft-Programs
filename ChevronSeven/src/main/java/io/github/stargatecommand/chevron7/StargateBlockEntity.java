package io.github.stargatecommand.chevron7;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.CopyOnWriteArraySet;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraftforge.common.world.ForgeChunkManager;
import net.minecraft.core.Direction;
import net.minecraft.core.registries.Registries;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.network.protocol.Packet;
import net.minecraft.network.protocol.game.ClientGamePacketListener;
import net.minecraft.network.protocol.game.ClientboundBlockEntityDataPacket;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.server.level.TicketType;
import net.minecraft.sounds.SoundEvent;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.entity.Entity;
import net.minecraft.world.entity.LivingEntity;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.ChunkPos;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;
import net.minecraft.world.phys.Vec3;

/**
 * Everything a gate knows and does: its address, dialing, the wormhole, travel and the iris.
 * Runs on the server; the client gets a copy of the fields to draw the gate.
 */
public class StargateBlockEntity extends BlockEntity
{
	public enum State
	{
		IDLE, DIALING, OPENING, OPEN, CLOSING, RESETTING;

		public boolean connected()
		{
			return this == OPENING || this == OPEN;
		}
	}

	public static final float STEP = 360.0F / GateAddress.SYMBOLS;
	public static final float SPIN_SPEED = 7.0F; // degrees per tick
	public static final int LOCK_TICKS = 12;
	public static final int FAST_LOCK_TICKS = 6;
	public static final int KAWOOSH_TICKS = 50;
	public static final int CLOSE_TICKS = 24;
	public static final int RESET_TICKS = 30;
	public static final int IRIS_TICKS = 24;
	private static final int FAST = 100;

	/** Chevron slots (every 40 degrees, 0 at the top) in the order they light; the top one locks last. */
	public static final int[] CHEVRON_ORDER = {1, 2, 3, 6, 7, 8, 0};

	public static final TicketType<ChunkPos> TICKET = TicketType.create("chevron7_wormhole", Comparator.comparingLong(ChunkPos::toLong), 300);

	// feedback codes, the same as Stargate Journey's where there is one
	public static final int SYMBOL_ENCODED = 1;
	public static final int CONNECTED = 2;
	public static final int DISCONNECTED = 7;
	public static final int AUTOCLOSE = 10;
	public static final int RESET = 0;
	public static final int SYMBOL_IN_ADDRESS = -2;
	public static final int SYMBOL_OUT_OF_BOUNDS = -3;
	public static final int INCOMPLETE_ADDRESS = -4;
	public static final int INVALID_ADDRESS = -5;
	public static final int TARGET_BUSY = -8;
	public static final int SELF_DIAL = -9;
	public static final int ALREADY_CONNECTED = -11;
	public static final int STARGATE_DESTROYED = -21;
	public static final int CONNECTION_LOST = -22;
	public static final int INTERRUPTED = -23;
	public static final int ADDRESS_FULL = -30;
	public static final int NOT_ALLOWED = -31;

	/** Receives gate events, e.g. the computers attached to the gate. */
	public interface Listener
	{
		void gateEvent(String name, Object... args);
	}

	// identity
	private int[] address = new int[0];
	private boolean registered;

	// dialing
	private final List<Integer> encoded = new ArrayList<>();
	private final ArrayDeque<Integer> queue = new ArrayDeque<>();
	private State state = State.IDLE;
	private boolean outgoing;
	private long stateTick;
	private int openTicks;
	private int pendingSymbol = -1;
	private long lockStart = -1;
	private int lockLength;

	// symbol ring
	private float rotFrom, rotTo;
	private long rotStart;
	private int rotDuration;
	private boolean rotating;

	// the other end
	@Nullable
	private ResourceKey<Level> remoteDimension;
	@Nullable
	private BlockPos remotePos;
	private int[] remoteAddress = new int[0];

	/**
	 * This gate's chunk is force-loaded (Forge's chunk manager) while it is connected. A region
	 * ticket alone keeps a chunk loaded, but a dimension with no players in it stops ticking its
	 * block entities: the gate on the Moon would never finish opening or closing.
	 */
	private boolean forced;

	private GateLook look = GateLook.SG1;

	// iris
	private boolean irisInstalled, irisClosed;
	private long irisTick = -1000;
	private float irisFrom;

	private int feedback;
	private String feedbackText = "";

	/**
	 * Which side of the event horizon each entity near it was last seen on (true: in front).
	 * A player's previous position is no help here: the server moves players between ticks,
	 * so by the time the gate looks, where they were and where they are are the same.
	 */
	private final Map<UUID, Boolean> sides = new HashMap<>();

	private final Set<Listener> listeners = new CopyOnWriteArraySet<>();
	/** The ComputerCraft peripheral of this gate, made when a computer first asks for it. */
	@Nullable
	public Object peripheral;

	public StargateBlockEntity(BlockPos pos, BlockState state)
	{
		super(Chevron7.STARGATE_ENTITY.get(), pos, state);
	}

	//============================================================================================
	// reading the state (both sides)
	//============================================================================================

	public int[] getAddress()
	{
		return address.clone();
	}

	public State getState()
	{
		return state;
	}

	public boolean isOutgoing()
	{
		return outgoing;
	}

	public long getStateTick()
	{
		return stateTick;
	}

	public int getOpenTicks()
	{
		return openTicks;
	}

	public List<Integer> getEncoded()
	{
		return List.copyOf(encoded);
	}

	public int getChevronsEngaged()
	{
		return encoded.size();
	}

	public int[] getRemoteAddress()
	{
		return remoteAddress.clone();
	}

	public int getPendingSymbol()
	{
		return pendingSymbol;
	}

	public Direction getFacing()
	{
		return getBlockState().getValue(StargateBlock.FACING);
	}

	/** How far the current chevron lock has gone, 0 to 1, or -1 when no chevron is locking. */
	public float lockProgress(float time)
	{
		if(lockStart < 0 || lockLength <= 0)
			return -1;
		return Math.min(1.0F, Math.max(0.0F, (time - lockStart) / lockLength));
	}

	/** Ring angle in degrees, clockwise as seen from the front. Symbol k sits under the top chevron at -k * STEP. */
	public float ringAngle(float time)
	{
		if(!rotating || rotDuration <= 0)
			return rotTo;
		float p = (time - rotStart) / rotDuration;
		if(p <= 0)
			return rotFrom;
		if(p >= 1)
			return rotTo;
		float eased = p * p * (3 - 2 * p);
		return rotFrom + (rotTo - rotFrom) * eased;
	}

	public boolean isRotating()
	{
		return rotating;
	}

	public int currentSymbol(float time)
	{
		int symbol = Math.round(-ringAngle(time) / STEP) % GateAddress.SYMBOLS;
		return symbol < 0 ? symbol + GateAddress.SYMBOLS : symbol;
	}

	public boolean hasIris()
	{
		return irisInstalled;
	}

	public boolean isIrisClosing()
	{
		return irisClosed;
	}

	/** 0 = open, 1 = closed. */
	public float irisProgress(float time)
	{
		if(!irisInstalled)
			return 0;
		float p = Math.min(1.0F, Math.max(0.0F, (time - irisTick) / IRIS_TICKS));
		return irisClosed ? irisFrom + (1 - irisFrom) * p : irisFrom * (1 - p);
	}

	public int getFeedback()
	{
		return feedback;
	}

	public String getFeedbackText()
	{
		return feedbackText;
	}

	private long now()
	{
		return level == null ? 0 : level.getGameTime();
	}

	public void addListener(Listener listener)
	{
		listeners.add(listener);
	}

	public void removeListener(Listener listener)
	{
		listeners.remove(listener);
	}

	private void fire(String name, Object... args)
	{
		for(Listener listener : listeners)
			listener.gateEvent(name, args);
	}

	//============================================================================================
	// actions
	//============================================================================================

	/**
	 * Adds a symbol to the address being dialed. The ring turns to it and the chevron locks,
	 * or with {@code fast} (the DHD) the chevron locks straight away.
	 */
	public int engageSymbol(int symbol, boolean fast)
	{
		if(state.connected() || state == State.CLOSING)
			return feedback(ALREADY_CONNECTED, "already_connected");
		if(symbol < 0 || symbol >= GateAddress.SYMBOLS)
			return feedback(SYMBOL_OUT_OF_BOUNDS, "symbol_out_of_bounds");
		List<Integer> planned = plannedSymbols();
		if(planned.contains(symbol))
			return feedback(SYMBOL_IN_ADDRESS, "symbol_in_address");
		if(planned.contains(GateAddress.POINT_OF_ORIGIN))
			return feedback(ADDRESS_FULL, "address_full");
		if(planned.size() >= GateAddress.LENGTH && symbol != GateAddress.POINT_OF_ORIGIN)
			return feedback(ADDRESS_FULL, "address_full");
		if(state == State.RESETTING)
		{
			state = State.IDLE;
			stateTick = now();
		}
		queue.add(symbol + (fast ? FAST : 0));
		setChanged();
		return feedback(SYMBOL_ENCODED, "symbol_encoded");
	}

	/** Symbols locked, being locked and waiting, in order. */
	public List<Integer> plannedSymbols()
	{
		List<Integer> planned = new ArrayList<>(encoded);
		if(pendingSymbol >= 0)
			planned.add(pendingSymbol);
		for(int q : queue)
			planned.add(q % FAST);
		return planned;
	}

	/** Dials a whole address, ring turning for each symbol. */
	public int dial(int[] target)
	{
		if(!GateAddress.valid(target))
			return feedback(INVALID_ADDRESS, "invalid_address");
		if(state.connected() || state == State.CLOSING)
			return feedback(ALREADY_CONNECTED, "already_connected");
		if(!plannedSymbols().isEmpty())
			abort();
		for(int symbol : target)
			engageSymbol(symbol, false);
		return engageSymbol(GateAddress.POINT_OF_ORIGIN, false);
	}

	/** The big red button of the DHD. */
	public int dhdButton()
	{
		if(state.connected())
			return disconnect(false);
		List<Integer> planned = plannedSymbols();
		if(planned.size() == GateAddress.LENGTH && !planned.contains(GateAddress.POINT_OF_ORIGIN))
			return engageSymbol(GateAddress.POINT_OF_ORIGIN, true);
		if(!planned.isEmpty())
		{
			abort();
			return feedback(RESET, "reset");
		}
		return feedback(INCOMPLETE_ADDRESS, "incomplete_address");
	}

	/**
	 * Closes the wormhole, or stops a dial in progress.
	 * @param force close even from the receiving side
	 */
	public int disconnect(boolean force)
	{
		if(state.connected())
		{
			if(!outgoing && !force && !Config.INCOMING_CAN_CLOSE.get())
				return feedback(NOT_ALLOWED, "only_the_dialing_gate_can_close");
			StargateBlockEntity remote = remote();
			closeLocal(DISCONNECTED, "disconnected");
			if(remote != null)
				remote.closeLocal(DISCONNECTED, "disconnected");
			return feedback;
		}
		if(!plannedSymbols().isEmpty())
		{
			abort();
			return feedback(RESET, "reset");
		}
		return feedback(RESET, "nothing_to_close");
	}

	private void abort()
	{
		stopDialing();
		fire("stargate_reset", RESET, "reset");
		feedback(RESET, "reset");
		sync();
	}

	private void stopDialing()
	{
		float angle = ringAngle(now());
		rotating = false;
		rotFrom = rotTo = normalize(angle);
		queue.clear();
		encoded.clear();
		pendingSymbol = -1;
		lockStart = -1;
		if(state == State.DIALING)
		{
			state = State.IDLE;
			stateTick = now();
		}
	}

	public GateLook getLook()
	{
		return look;
	}

	public void setLook(GateLook look)
	{
		this.look = look;
		sync();
	}

	public void installIris()
	{
		irisInstalled = true;
		irisClosed = false;
		irisFrom = 0;
		irisTick = now() - IRIS_TICKS;
		sync();
	}

	public boolean setIris(boolean closed)
	{
		if(!irisInstalled)
			return false;
		if(closed == irisClosed)
			return true;
		long now = now();
		irisFrom = irisProgress(now);
		irisClosed = closed;
		irisTick = now;
		sound(closed ? SoundEvents.PISTON_EXTEND : SoundEvents.PISTON_CONTRACT, 1.0F, 0.55F);
		sync();
		return true;
	}

	public boolean sendMessage(String message)
	{
		StargateBlockEntity remote = state.connected() ? remote() : null;
		if(remote == null)
			return false;
		remote.fire("stargate_message_received", message);
		return true;
	}

	private int feedback(int code, String text)
	{
		feedback = code;
		feedbackText = text;
		return code;
	}

	//============================================================================================
	// server ticking
	//============================================================================================

	public static void serverTick(Level level, BlockPos pos, BlockState blockState, StargateBlockEntity gate)
	{
		gate.tickServer((ServerLevel) level);
	}

	private void tickServer(ServerLevel level)
	{
		if(!registered)
			register(level);
		long now = level.getGameTime();
		switch(state)
		{
			case IDLE, DIALING -> tickDialing(level, now);
			case OPENING ->
			{
				if(now - stateTick >= KAWOOSH_TICKS)
				{
					setState(State.OPEN, now);
					sync();
				}
				else
					kawoosh(level, now);
			}
			case OPEN -> tickOpen(level, now);
			case CLOSING ->
			{
				if(now - stateTick >= CLOSE_TICKS)
				{
					encoded.clear();
					remoteAddress = new int[0];
					setState(State.IDLE, now);
					sync();
				}
			}
			case RESETTING ->
			{
				if(now - stateTick >= RESET_TICKS)
				{
					setState(State.IDLE, now);
					sync();
				}
			}
		}
		if(forced && !state.connected())
			force(false);
		if(state.connected())
		{
			if(now % 20 == 0 && !remoteStillConnected())
				closeLocal(CONNECTION_LOST, "connection_lost");
			else if(outgoing && now % 100 == 0)
				keepLoaded(level);
		}
	}

	private void tickDialing(ServerLevel level, long now)
	{
		if(rotating)
		{
			if(now >= rotStart + rotDuration)
			{
				rotating = false;
				rotFrom = rotTo = normalize(rotTo);
				fire("stargate_rotation_stopped");
				lockStart = now;
				lockLength = LOCK_TICKS;
				sound(SoundEvents.IRON_DOOR_CLOSE, 0.8F, 0.6F);
				sync();
			}
			return;
		}
		if(lockStart >= 0)
		{
			if(now >= lockStart + lockLength)
			{
				lockStart = -1;
				finishLock(level, now);
			}
			return;
		}
		Integer next = queue.poll();
		if(next == null)
			return;
		boolean fast = next >= FAST;
		int symbol = next % FAST;
		pendingSymbol = symbol;
		if(state == State.IDLE)
			setState(State.DIALING, now);
		if(fast)
		{
			lockStart = now;
			lockLength = FAST_LOCK_TICKS;
		}
		else
		{
			float angle = normalize(ringAngle(now));
			float target = normalize(-symbol * STEP);
			// the ring turns one way, then the other
			float delta = encoded.size() % 2 == 0 ? positive(target - angle) : -positive(angle - target);
			if(Math.abs(delta) < 0.01F)
			{
				lockStart = now;
				lockLength = LOCK_TICKS;
			}
			else
			{
				rotating = true;
				rotFrom = angle;
				rotTo = angle + delta;
				rotStart = now;
				rotDuration = Math.max(4, (int) Math.ceil(Math.abs(delta) / SPIN_SPEED));
				fire("stargate_rotation_started");
				sound(SoundEvents.GRINDSTONE_USE, 0.7F, 0.5F);
			}
		}
		sync();
	}

	private void finishLock(ServerLevel level, long now)
	{
		int symbol = pendingSymbol;
		pendingSymbol = -1;
		encoded.add(symbol);
		int n = encoded.size();
		sound(SoundEvents.IRON_TRAPDOOR_CLOSE, 1.0F, 0.6F);
		fire("stargate_chevron_engaged", n, n, false, symbol);
		if(symbol == GateAddress.POINT_OF_ORIGIN)
			connect(level, now);
		else
			sync();
	}

	private void connect(ServerLevel level, long now)
	{
		if(encoded.size() != GateAddress.LENGTH + 1)
		{
			fail(INCOMPLETE_ADDRESS, "incomplete_address", now);
			return;
		}
		int[] target = new int[GateAddress.LENGTH];
		for(int i = 0; i < GateAddress.LENGTH; i++)
			target[i] = encoded.get(i);
		if(GateAddress.same(target, address))
		{
			fail(SELF_DIAL, "self_dial", now);
			return;
		}
		GateNetwork network = GateNetwork.get(level.getServer());
		GateNetwork.Entry entry = network.find(target);
		if(entry == null && PlanetGates.siteFor(level.getServer(), target) != null)
			entry = network.find(target); // a planet nobody had been to: its gate now exists
		ServerLevel targetLevel = entry == null ? null : level.getServer().getLevel(entry.dimension());
		if(entry == null || targetLevel == null)
		{
			fail(INVALID_ADDRESS, "invalid_address", now);
			return;
		}
		ChunkPos chunk = new ChunkPos(entry.pos());
		targetLevel.getChunkSource().addRegionTicket(TICKET, chunk, 2, chunk);
		targetLevel.getChunk(chunk.x, chunk.z); // loads it now
		if(!(targetLevel.getBlockEntity(entry.pos()) instanceof StargateBlockEntity other) || !GateAddress.same(other.address, target))
		{
			// the gate is gone
			network.remove(target, entry.dimension(), entry.pos());
			fail(INVALID_ADDRESS, "invalid_address", now);
			return;
		}
		// a gate in a dimension nobody is in hasn't ticked: let it catch up before calling it busy
		other.settle(targetLevel.getGameTime());
		if(other.state.connected() || other.state == State.CLOSING)
		{
			fail(TARGET_BUSY, "target_busy", now);
			return;
		}

		queue.clear();
		outgoing = true;
		remoteDimension = targetLevel.dimension();
		remotePos = other.getBlockPos();
		remoteAddress = target;
		openTicks = 0;
		setState(State.OPENING, now);
		feedback(CONNECTED, "connected");
		keepLoaded(level);
		other.acceptIncoming(this, targetLevel.getGameTime());
		force(true);
		other.force(true);
		fire("stargate_outgoing_wormhole", GateAddress.list(target));
		sound(SoundEvents.GENERIC_EXPLODE, 1.2F, 0.6F);
		sync();
	}

	private void acceptIncoming(StargateBlockEntity caller, long now)
	{
		if(!plannedSymbols().isEmpty())
		{
			stopDialing();
			fire("stargate_reset", INTERRUPTED, "interrupted_by_incoming_connection");
		}
		outgoing = false;
		remoteDimension = caller.level.dimension();
		remotePos = caller.getBlockPos();
		remoteAddress = caller.address.clone();
		openTicks = 0;
		encoded.clear();
		for(int symbol : caller.address)
			encoded.add(symbol);
		encoded.add(GateAddress.POINT_OF_ORIGIN);
		setState(State.OPENING, now);
		for(int i = 0; i < encoded.size(); i++)
			fire("stargate_chevron_engaged", i + 1, i + 1, true, encoded.get(i));
		fire("stargate_incoming_wormhole", GateAddress.list(remoteAddress));
		sound(SoundEvents.GENERIC_EXPLODE, 1.2F, 0.6F);
		sync();
	}

	private void fail(int code, String text, long now)
	{
		feedback(code, text);
		stopDialing();
		setState(State.RESETTING, now);
		fire("stargate_reset", code, text);
		sound(SoundEvents.BEACON_DEACTIVATE, 1.0F, 1.4F);
		sync();
	}

	private void closeLocal(int code, String text)
	{
		long now = now();
		force(false);
		sides.clear();
		feedback(code, text);
		remoteDimension = null;
		remotePos = null;
		setState(State.CLOSING, now);
		fire("stargate_disconnected", code, text);
		sound(SoundEvents.BEACON_DEACTIVATE, 1.2F, 0.8F);
		sync();
	}

	private void tickOpen(ServerLevel level, long now)
	{
		openTicks++;
		// the beacon hum is only heard within 7 blocks at volume 1; above 1, the volume
		// stretches that range instead of making it louder, so 2.5 carries about 17 blocks
		if(openTicks % 80 == 1)
			sound(SoundEvents.BEACON_AMBIENT, 2.5F, 0.7F);
		if(!outgoing)
			return;
		if(openTicks >= Config.MAX_OPEN_SECONDS.get() * 20)
		{
			StargateBlockEntity remote = remote();
			closeLocal(AUTOCLOSE, "autoclose");
			if(remote != null)
				remote.closeLocal(AUTOCLOSE, "autoclose");
			return;
		}
		transport(level, now);
	}

	private void setState(State newState, long now)
	{
		boolean wasLit = state.connected();
		state = newState;
		stateTick = now;
		boolean lit = newState.connected();
		if(lit != wasLit && level != null)
			setLit(lit);
	}

	private void setLit(boolean lit)
	{
		BlockState core = getBlockState();
		if(core.getValue(StargateBlock.LIT) != lit)
			level.setBlock(worldPosition, core.setValue(StargateBlock.LIT, lit), Block.UPDATE_ALL);
		Direction facing = getFacing();
		for(int part = 0; part < GateShape.FRAME.length; part++)
		{
			BlockPos cell = GateShape.frameCell(worldPosition, facing, part);
			BlockState frame = level.getBlockState(cell);
			if(frame.is(Chevron7.GATE_FRAME.get()) && frame.getValue(GateFrameBlock.LIT) != lit)
				level.setBlock(cell, frame.setValue(GateFrameBlock.LIT, lit), Block.UPDATE_ALL);
		}
	}

	//============================================================================================
	// the other end
	//============================================================================================

	@Nullable
	public StargateBlockEntity remote()
	{
		if(remoteDimension == null || remotePos == null || level == null || level.getServer() == null)
			return null;
		ServerLevel other = level.getServer().getLevel(remoteDimension);
		if(other == null || !other.isLoaded(remotePos))
			return null;
		return other.getBlockEntity(remotePos) instanceof StargateBlockEntity gate ? gate : null;
	}

	private boolean remoteStillConnected()
	{
		StargateBlockEntity remote = remote();
		return remote != null && remote.state.connected() && remote.outgoing != outgoing
				&& worldPosition.equals(remote.remotePos) && level.dimension().equals(remote.remoteDimension);
	}

	private void keepLoaded(ServerLevel level)
	{
		ChunkPos here = new ChunkPos(worldPosition);
		level.getChunkSource().addRegionTicket(TICKET, here, 2, here);
		if(remoteDimension != null && remotePos != null)
		{
			ServerLevel other = level.getServer().getLevel(remoteDimension);
			if(other != null)
			{
				ChunkPos there = new ChunkPos(remotePos);
				other.getChunkSource().addRegionTicket(TICKET, there, 2, there);
			}
		}
	}

	/** Force-loads this gate's chunk, or lets it go. The ticket is saved, so a wormhole survives a restart. */
	private void force(boolean on)
	{
		if(on == forced || !(level instanceof ServerLevel server))
			return;
		ChunkPos chunk = new ChunkPos(worldPosition);
		ForgeChunkManager.forceChunk(server, Chevron7.MOD_ID, worldPosition, chunk.x, chunk.z, on, true);
		forced = on;
		setChanged();
	}

	/**
	 * Does what the gate would have done had it been ticking: a gate in a dimension with no
	 * players in it stands still, so it can be left closing, or open to a gate that has gone.
	 */
	private void settle(long now)
	{
		if(state == State.CLOSING && now - stateTick >= CLOSE_TICKS)
		{
			encoded.clear();
			remoteAddress = new int[0];
			setState(State.IDLE, now);
			sync();
		}
		else if(state == State.RESETTING && now - stateTick >= RESET_TICKS)
		{
			setState(State.IDLE, now);
			sync();
		}
		else if(state.connected() && !remoteStillConnected())
		{
			force(false);
			feedback(CONNECTION_LOST, "connection_lost");
			remoteDimension = null;
			remotePos = null;
			remoteAddress = new int[0];
			encoded.clear();
			setState(State.IDLE, now);
			fire("stargate_disconnected", CONNECTION_LOST, "connection_lost");
			sync();
		}
	}

	//============================================================================================
	// kawoosh and travel
	//============================================================================================

	private void kawoosh(ServerLevel level, long now)
	{
		float p = (float) (now - stateTick) / KAWOOSH_TICKS;
		if(p < 0.15F || p > 0.6F || !Config.KAWOOSH_KILLS.get() || irisProgress(now) > 0.5F)
			return;
		Vec3 center = GateShape.center(worldPosition);
		Vec3 normal = GateShape.normal(getFacing());
		AABB box = new AABB(center, center).inflate(3.0).expandTowards(normal.scale(4.5));
		for(LivingEntity entity : level.getEntitiesOfClass(LivingEntity.class, box))
		{
			Vec3 offset = entity.position().add(0, entity.getBbHeight() / 2, 0).subtract(center);
			double depth = offset.dot(normal);
			double lateral = offset.subtract(normal.scale(depth)).length();
			if(depth > -0.3 && depth < 4.2 && lateral < GateShape.HORIZON_RADIUS * (1.0 - depth / 6.0))
				entity.hurt(new net.minecraft.world.damagesource.DamageSource(level.registryAccess().registryOrThrow(Registries.DAMAGE_TYPE)
						.getHolderOrThrow(Chevron7.KAWOOSH)), 1000.0F);
		}
	}

	private void transport(ServerLevel level, long now)
	{
		Direction facing = getFacing();
		Vec3 center = GateShape.center(worldPosition);
		Vec3 normal = GateShape.normal(facing);
		AABB box = new AABB(center, center).inflate(GateShape.HORIZON_RADIUS + 0.5).inflate(Math.abs(normal.x) * 2, 0, Math.abs(normal.z) * 2);
		List<Entity> travelers = new ArrayList<>();
		Map<Entity, Boolean> fromFront = new HashMap<>();
		Map<UUID, Boolean> seen = new HashMap<>();
		for(Entity entity : level.getEntities((Entity) null, box, e -> e.isAlive() && !e.isSpectator() && !e.isPassenger()))
		{
			Vec3 middle = entity.position().add(0, entity.getBbHeight() / 2, 0);
			double depthNow = middle.subtract(center).dot(normal);
			Boolean side = sides.get(entity.getUUID());
			if(side == null)
			{
				Vec3 before = new Vec3(entity.xo, entity.yo + entity.getBbHeight() / 2, entity.zo);
				side = before.subtract(center).dot(normal) > 0;
			}
			// remembered while clear of the horizon; inside it, the side they came from counts
			seen.put(entity.getUUID(), Math.abs(depthNow) >= 0.35 ? depthNow > 0 : side);
			if(now - entity.getPersistentData().getLong("chevron7_arrived") < 10)
				continue;
			boolean crossed = Math.abs(depthNow) < 0.35 || side != (depthNow > 0);
			if(!crossed)
				continue;
			Vec3 flat = middle.subtract(center).subtract(normal.scale(depthNow));
			if(flat.length() > GateShape.HORIZON_RADIUS - 0.1)
				continue;
			travelers.add(entity);
			fromFront.put(entity, side);
		}
		sides.clear();
		sides.putAll(seen);
		if(travelers.isEmpty())
			return;
		StargateBlockEntity remote = remote();
		if(remote == null)
			return;
		for(Entity entity : travelers)
			send(level, entity, remote, center, normal, fromFront.get(entity), now);
	}

	private void send(ServerLevel level, Entity entity, StargateBlockEntity remote, Vec3 center, Vec3 normal, boolean fromFront, long now)
	{
		// moving in from the front goes against the normal
		Vec3 travel = fromFront ? normal.scale(-1) : normal;
		Vec3 travelRight = new Vec3(-travel.z, 0, travel.x);
		Vec3 middle = entity.position().add(0, entity.getBbHeight() / 2, 0).subtract(center);
		double across = middle.dot(travelRight);
		double up = middle.y;

		String type = net.minecraftforge.registries.ForgeRegistries.ENTITY_TYPES.getKey(entity.getType()).toString();
		String name = entity.getName().getString();
		String uuid = entity.getStringUUID();

		if(remote.irisProgress(remote.now()) > 0.5F)
		{
			// the iris is closed on the other side: back out of the horizon the way they came, every
			// time they try (no grace ticks, or someone who keeps walking ends up behind the gate)
			double past = entity.position().subtract(center).dot(travel);
			Vec3 out = entity.position().subtract(travel.scale(past + 0.6 + entity.getBbWidth() / 2));
			if(entity instanceof ServerPlayer player)
				player.connection.teleport(out.x, out.y, out.z, player.getYRot(), player.getXRot()); // the client has to agree
			else
				entity.teleportTo(out.x, out.y, out.z);
			entity.setDeltaMovement(travel.scale(-0.6).add(0, 0.2, 0));
			entity.hurtMarked = true;
			long lastThud = entity.getPersistentData().getLong("chevron7_thud");
			if(now - lastThud > 20 || now < lastThud)
			{
				entity.getPersistentData().putLong("chevron7_thud", now);
				remote.fire("iris_thud", type, name, uuid);
				remote.sound(SoundEvents.ANVIL_LAND, 0.7F, 0.5F);
			}
			return;
		}

		fire("stargate_deconstructing_entity", type, name, uuid, false);
		Direction exitFacing = remote.getFacing();
		Vec3 exit = GateShape.normal(exitFacing);
		Vec3 exitRight = new Vec3(-exit.z, 0, exit.x);
		Vec3 target = GateShape.center(remote.getBlockPos()).add(exitRight.scale(across)).add(0, up, 0)
				.add(exit.scale(0.9 + entity.getBbWidth() / 2));
		double feet = target.y - entity.getBbHeight() / 2;

		Vec3 velocity = entity.getDeltaMovement();
		double forward = Math.max(0.05, velocity.dot(travel));
		double sideways = velocity.dot(travelRight);
		Vec3 newVelocity = exit.scale(forward).add(exitRight.scale(sideways)).add(0, velocity.y, 0);
		float yaw = entity.getYRot() + (yawOf(exit) - yawOf(travel));

		ServerLevel destination = (ServerLevel) remote.getLevel();
		Entity arrived = entity;
		if(entity instanceof ServerPlayer player)
		{
			player.teleportTo(destination, target.x, feet, target.z, yaw, player.getXRot());
		}
		else if(destination == level)
		{
			entity.teleportTo(target.x, feet, target.z);
			entity.setYRot(yaw);
			entity.setYHeadRot(yaw);
		}
		else
		{
			entity.teleportTo(destination, target.x, feet, target.z, Set.of(), yaw, entity.getXRot());
			arrived = null; // a copy of the entity arrives in the other dimension
		}
		if(arrived != null)
		{
			arrived.setDeltaMovement(newVelocity);
			arrived.hurtMarked = true;
			arrived.getPersistentData().putLong("chevron7_arrived", destination.getGameTime());
		}
		sound(SoundEvents.ENDERMAN_TELEPORT, 0.6F, 0.5F);
		remote.sound(SoundEvents.ENDERMAN_TELEPORT, 0.6F, 0.5F);
		remote.fire("stargate_reconstructing_entity", type, name, uuid);
	}

	private static float yawOf(Vec3 direction)
	{
		return (float) Math.toDegrees(Math.atan2(-direction.x, direction.z));
	}

	//============================================================================================
	// network and lifecycle
	//============================================================================================

	/** Gives a gate made by world generation its address (a planet's gate); kept if no other gate has it. */
	public void presetAddress(int[] preset)
	{
		if(GateAddress.valid(preset))
			address = preset.clone();
	}

	/** Puts the gate on the network now, instead of on its first tick. */
	public void ensureRegistered(ServerLevel level)
	{
		if(!registered)
			register(level);
	}

	private void register(ServerLevel level)
	{
		registered = true;
		GateNetwork network = GateNetwork.get(level.getServer());
		if(GateAddress.valid(address))
		{
			GateNetwork.Entry entry = network.find(address);
			if(entry == null || (entry.dimension().equals(level.dimension()) && entry.pos().equals(worldPosition)))
			{
				network.put(address, level.dimension(), worldPosition);
				return;
			}
			// another gate has this address (a copied gate): this one gets a new one
		}
		int[] fresh;
		do
			fresh = GateAddress.random(level.getRandom());
		while(network.find(fresh) != null);
		address = fresh;
		network.put(address, level.dimension(), worldPosition);
		sync();
	}

	/** The block is being broken. */
	public void onBroken()
	{
		if(!(level instanceof ServerLevel server))
			return;
		force(false);
		if(state.connected())
		{
			StargateBlockEntity remote = remote();
			if(remote != null)
				remote.closeLocal(STARGATE_DESTROYED, "stargate_destroyed");
		}
		if(GateAddress.valid(address))
			GateNetwork.get(server.getServer()).remove(address, server.dimension(), worldPosition);
		if(irisInstalled)
			Block.popResource(server, worldPosition.above(), new ItemStack(Chevron7.IRIS.get()));
	}

	private void sound(SoundEvent sound, float volume, float pitch)
	{
		if(level != null && !level.isClientSide())
			level.playSound(null, worldPosition.above(3), sound, SoundSource.BLOCKS, volume, pitch);
	}

	private void sync()
	{
		setChanged();
		if(level != null && !level.isClientSide())
			level.sendBlockUpdated(worldPosition, getBlockState(), getBlockState(), Block.UPDATE_CLIENTS);
	}

	private static float normalize(float angle)
	{
		float a = angle % 360.0F;
		return a < 0 ? a + 360.0F : a;
	}

	private static float positive(float angle)
	{
		return normalize(angle);
	}

	@Override
	public AABB getRenderBoundingBox()
	{
		return new AABB(worldPosition).inflate(7.0, 0, 7.0).expandTowards(0, 8.0, 0);
	}

	//============================================================================================
	// saving and syncing
	//============================================================================================

	@Override
	protected void saveAdditional(CompoundTag tag)
	{
		super.saveAdditional(tag);
		tag.putIntArray("Address", address);
		tag.putIntArray("Encoded", encoded);
		tag.putIntArray("Queue", new ArrayList<>(queue));
		tag.putString("State", state.name());
		tag.putBoolean("Outgoing", outgoing);
		tag.putLong("StateTick", stateTick);
		tag.putInt("OpenTicks", openTicks);
		tag.putInt("PendingSymbol", pendingSymbol);
		tag.putLong("LockStart", lockStart);
		tag.putInt("LockLength", lockLength);
		tag.putFloat("RotFrom", rotFrom);
		tag.putFloat("RotTo", rotTo);
		tag.putLong("RotStart", rotStart);
		tag.putInt("RotDuration", rotDuration);
		tag.putBoolean("Rotating", rotating);
		if(remoteDimension != null && remotePos != null)
		{
			tag.putString("RemoteDimension", remoteDimension.location().toString());
			tag.putLong("RemotePos", remotePos.asLong());
		}
		tag.putIntArray("RemoteAddress", remoteAddress);
		tag.putBoolean("Forced", forced);
		tag.putString("Look", look.id);
		tag.putBoolean("Iris", irisInstalled);
		tag.putBoolean("IrisClosed", irisClosed);
		tag.putLong("IrisTick", irisTick);
		tag.putFloat("IrisFrom", irisFrom);
		tag.putInt("Feedback", feedback);
		tag.putString("FeedbackText", feedbackText);
	}

	@Override
	public void load(CompoundTag tag)
	{
		super.load(tag);
		address = tag.getIntArray("Address");
		encoded.clear();
		for(int symbol : tag.getIntArray("Encoded"))
			encoded.add(symbol);
		queue.clear();
		for(int q : tag.getIntArray("Queue"))
			queue.add(q);
		try
		{
			state = State.valueOf(tag.getString("State"));
		}
		catch(IllegalArgumentException e)
		{
			state = State.IDLE;
		}
		outgoing = tag.getBoolean("Outgoing");
		stateTick = tag.getLong("StateTick");
		openTicks = tag.getInt("OpenTicks");
		pendingSymbol = tag.contains("PendingSymbol") ? tag.getInt("PendingSymbol") : -1;
		lockStart = tag.contains("LockStart") ? tag.getLong("LockStart") : -1;
		lockLength = tag.getInt("LockLength");
		rotFrom = tag.getFloat("RotFrom");
		rotTo = tag.getFloat("RotTo");
		rotStart = tag.getLong("RotStart");
		rotDuration = tag.getInt("RotDuration");
		rotating = tag.getBoolean("Rotating");
		ResourceLocation dimension = tag.contains("RemoteDimension") ? ResourceLocation.tryParse(tag.getString("RemoteDimension")) : null;
		remoteDimension = dimension == null ? null : ResourceKey.create(Registries.DIMENSION, dimension);
		remotePos = tag.contains("RemotePos") ? BlockPos.of(tag.getLong("RemotePos")) : null;
		remoteAddress = tag.getIntArray("RemoteAddress");
		forced = tag.getBoolean("Forced");
		GateLook saved = GateLook.byId(tag.getString("Look"));
		look = saved == null ? GateLook.SG1 : saved;
		irisInstalled = tag.getBoolean("Iris");
		irisClosed = tag.getBoolean("IrisClosed");
		irisTick = tag.contains("IrisTick") ? tag.getLong("IrisTick") : -1000;
		irisFrom = tag.getFloat("IrisFrom");
		feedback = tag.getInt("Feedback");
		feedbackText = tag.getString("FeedbackText");
		registered = false;
	}

	@Override
	public CompoundTag getUpdateTag()
	{
		return saveWithoutMetadata();
	}

	@Override
	public Packet<ClientGamePacketListener> getUpdatePacket()
	{
		return ClientboundBlockEntityDataPacket.create(this);
	}
}
