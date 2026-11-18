package io.github.stargatecommand.chevron7.compat;

import java.util.StringJoiner;

import javax.annotation.Nullable;

import dan200.computercraft.api.lua.IArguments;
import dan200.computercraft.api.lua.LuaException;
import dan200.computercraft.api.lua.LuaFunction;
import dan200.computercraft.api.lua.MethodResult;
import dan200.computercraft.api.peripheral.AttachedComputerSet;
import dan200.computercraft.api.peripheral.IComputerAccess;
import dan200.computercraft.api.peripheral.IPeripheral;
import io.github.stargatecommand.chevron7.GateNetwork;
import io.github.stargatecommand.chevron7.PlanetGates;
import io.github.stargatecommand.chevron7.SGAddress;
import io.github.stargatecommand.chevron7.SGInterfaceBlockEntity;
import io.github.stargatecommand.chevron7.StargateBlockEntity;
import io.github.stargatecommand.chevron7.StargateBlockEntity.State;
import net.minecraft.server.level.ServerLevel;

/**
 * The SG computer interface, as a computer sees it: a "stargate" peripheral with SGCraft's
 * method names and events, and letter addresses such as "1KA09KTHY". Programs written for
 * SGCraft, such as the Gate Room and the Personal Dialer, drive Chevron Seven gates through it.
 * Works with every kind of gate; a Stargate Network gate turns its ring to each letter.
 */
public class SGInterfacePeripheral implements IPeripheral, StargateBlockEntity.Listener, SGInterfaceBlockEntity.Linked
{
	public static final String TYPE = "stargate";

	private final SGInterfaceBlockEntity block;
	private final AttachedComputerSet computers = new AttachedComputerSet();
	/** The gate whose events reach the computers. */
	@Nullable
	private volatile StargateBlockEntity linked;

	public SGInterfacePeripheral(SGInterfaceBlockEntity block)
	{
		this.block = block;
	}

	@Override
	public String getType()
	{
		return TYPE;
	}

	@Override
	public Object getTarget()
	{
		return block;
	}

	@Override
	public boolean equals(@Nullable IPeripheral other)
	{
		return other instanceof SGInterfacePeripheral peripheral && peripheral.block == block;
	}

	@Override
	public void attach(IComputerAccess computer)
	{
		computers.add(computer);
	}

	@Override
	public void detach(IComputerAccess computer)
	{
		computers.remove(computer);
		if(!computers.hasComputers())
		{
			// the listener set is thread-safe, so this is fine off the server thread
			StargateBlockEntity gate = linked;
			if(gate != null)
				gate.removeListener(this);
			linked = null;
		}
	}

	/** On the server thread: follows the nearest gate, so a gate placed or broken later is picked up. */
	@Override
	public void relink()
	{
		StargateBlockEntity gate = computers.hasComputers() ? block.gate() : null;
		StargateBlockEntity old = linked;
		if(gate == old)
			return;
		if(old != null)
			old.removeListener(this);
		if(gate != null)
			gate.addListener(this);
		linked = gate;
	}

	private StargateBlockEntity gate() throws LuaException
	{
		relink();
		StargateBlockEntity gate = block.gate();
		if(gate == null)
			throw new LuaException("No stargate within " + io.github.stargatecommand.chevron7.SGInterfaceBlock.RANGE + " blocks of the interface");
		return gate;
	}

	//============================================================================================
	// events, as SGCraft names them
	//============================================================================================

	private static String sgState(String name)
	{
		return sgState(State.valueOf(name));
	}

	private static String sgState(State state)
	{
		return switch(state)
		{
			case DIALING -> "Dialling";
			case OPENING -> "Opening";
			case OPEN -> "Connected";
			case CLOSING -> "Closing";
			default -> "Idle";
		};
	}

	private void queue(String event, Object... args)
	{
		computers.forEach(computer -> {
			Object[] withName = new Object[args.length + 1];
			withName[0] = computer.getAttachmentName();
			System.arraycopy(args, 0, withName, 1, args.length);
			computer.queueEvent(event, withName);
		});
	}

	@Override
	public void gateEvent(String name, Object... args)
	{
		StargateBlockEntity gate = linked;
		if(gate == null)
			return;
		switch(name)
		{
			case "_state" ->
			{
				String from = sgState((String) args[0]), to = sgState((String) args[1]);
				if(to.equals("Opening"))
					queue(gate.isOutgoing() ? "sgDialOut" : "sgDialIn", letters(gate.getRemoteAddress()));
				if(!from.equals(to))
					queue("sgStargateStateChange", to, from);
			}
			case "stargate_chevron_engaged" ->
			{
				int number = ((Number) args[0]).intValue();
				int symbol = ((Number) args[3]).intValue();
				queue("sgChevronEngaged", number, gate.style().letters() ? SGAddress.letters(java.util.List.of(symbol)) : String.valueOf(symbol));
			}
			case "_iris" ->
			{
				boolean closing = (Boolean) args[0];
				queue("sgIrisStateChange", closing ? "Closing" : "Opening", closing ? "Open" : "Closed");
			}
			case "stargate_message_received" -> queue("sgMessageReceived", args);
			default -> {}
		}
	}

	private static String letters(int[] address)
	{
		String letters = SGAddress.encode(address);
		return letters == null ? "" : letters;
	}

	//============================================================================================
	// state
	//============================================================================================

	/** The state ("Idle", "Dialling", "Opening", "Connected" or "Closing"), the chevrons locked, and the direction. */
	@LuaFunction(mainThread = true)
	public final MethodResult stargateState() throws LuaException
	{
		StargateBlockEntity gate = gate();
		State state = gate.getState();
		String direction = "";
		if(state == State.DIALING)
			direction = "Outgoing";
		else if(state.connected() || state == State.CLOSING)
			direction = gate.isOutgoing() ? "Outgoing" : "Incoming";
		return MethodResult.of(sgState(state), gate.getChevronsEngaged(), direction);
	}

	@LuaFunction(mainThread = true)
	public final String localAddress() throws LuaException
	{
		return letters(gate().getAddress());
	}

	@LuaFunction(mainThread = true)
	public final String remoteAddress() throws LuaException
	{
		StargateBlockEntity gate = gate();
		return gate.getState().connected() ? letters(gate.getRemoteAddress()) : "";
	}

	/** The letters locked so far on a Stargate Network gate; the whole address once connected. */
	@LuaFunction(mainThread = true)
	public final String dialledAddress() throws LuaException
	{
		StargateBlockEntity gate = gate();
		if(gate.getState().connected())
			return gate.isOutgoing() ? letters(gate.getRemoteAddress()) : letters(gate.getAddress());
		return gate.style().letters() ? SGAddress.letters(gate.getEncoded()) : "";
	}

	@LuaFunction(mainThread = true)
	public final boolean isInitiator() throws LuaException
	{
		StargateBlockEntity gate = gate();
		return gate.getState().connected() && gate.isOutgoing();
	}

	/** Chevron Seven gates need no power: both read 0. */
	@LuaFunction(mainThread = true)
	public final double energyAvailable() throws LuaException
	{
		gate();
		return 0;
	}

	@LuaFunction(mainThread = true)
	public final double energyToDial(String address) throws LuaException
	{
		gate();
		return 0;
	}

	/** "Chevron Seven", and the kind of gate; not in SGCraft, but harmless to programs written for it. */
	@LuaFunction(mainThread = true)
	public final String getStargateVariant() throws LuaException
	{
		return gate().style().variant;
	}

	//============================================================================================
	// dialing
	//============================================================================================

	/** Dials a letter address. Errors are SGCraft's message keys, e.g. "unknownAddress". */
	@LuaFunction(mainThread = true)
	public final void dial(String address) throws LuaException
	{
		StargateBlockEntity gate = gate();
		if(gate.getState() != State.IDLE && gate.getState() != State.RESETTING || !gate.plannedSymbols().isEmpty())
			throw new LuaException("selfBusy");
		int[] target = SGAddress.decode(address);
		if(target == null)
			throw new LuaException(SGAddress.wellFormed(address) ? "unknownAddress" : "malformedAddress");
		if(java.util.Arrays.equals(target, gate.getAddress()))
			throw new LuaException("diallingItself");
		if(gate.getLevel() instanceof ServerLevel level && GateNetwork.get(level.getServer()).find(target) == null
				&& !PlanetGates.isPlanetAddress(level.getServer(), target))
			throw new LuaException("unknownAddress");
		int result = gate.dialLetters(address);
		if(result < 0)
			throw new LuaException(gate.getFeedbackText());
	}

	@LuaFunction(mainThread = true)
	public final void disconnect() throws LuaException
	{
		StargateBlockEntity gate = gate();
		int result = gate.disconnect(false);
		if(result == StargateBlockEntity.NOT_ALLOWED)
			throw new LuaException("Only the dialing gate can close the wormhole");
	}

	/** Sends text through the open wormhole; the other side gets an sgMessageReceived event. */
	@LuaFunction(mainThread = true)
	public final boolean sendMessage(IArguments arguments) throws LuaException
	{
		StringJoiner text = new StringJoiner(" ");
		for(int i = 0; i < arguments.count(); i++)
			text.add(String.valueOf(arguments.get(i)));
		return gate().sendMessage(text.toString());
	}

	//============================================================================================
	// iris
	//============================================================================================

	/** "Offline" without an iris, otherwise "Open", "Opening", "Closing" or "Closed". */
	@LuaFunction(mainThread = true)
	public final String irisState() throws LuaException
	{
		StargateBlockEntity gate = gate();
		if(!gate.hasIris())
			return "Offline";
		float p = gate.irisProgress(gate.getLevel() == null ? 0 : gate.getLevel().getGameTime());
		if(gate.isIrisClosing())
			return p >= 1 ? "Closed" : "Closing";
		return p <= 0 ? "Open" : "Opening";
	}

	@LuaFunction(mainThread = true)
	public final void openIris() throws LuaException
	{
		if(!gate().setIris(false))
			throw new LuaException("Gate has no iris");
	}

	@LuaFunction(mainThread = true)
	public final void closeIris() throws LuaException
	{
		if(!gate().setIris(true))
			throw new LuaException("Gate has no iris");
	}
}
