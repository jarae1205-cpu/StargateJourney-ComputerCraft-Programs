package io.github.stargatecommand.chevron7.compat;

import java.util.List;
import java.util.Map;

import javax.annotation.Nullable;

import dan200.computercraft.api.lua.LuaFunction;
import dan200.computercraft.api.lua.MethodResult;
import dan200.computercraft.api.peripheral.AttachedComputerSet;
import dan200.computercraft.api.peripheral.IComputerAccess;
import dan200.computercraft.api.peripheral.IPeripheral;
import io.github.stargatecommand.chevron7.GateAddress;
import io.github.stargatecommand.chevron7.StargateBlockEntity;

/**
 * The gate as a computer sees it. The method names and events follow Stargate Journey's
 * crystal interface, so programs written for that work here too.
 */
public class StargatePeripheral implements IPeripheral, StargateBlockEntity.Listener
{
	public static final String TYPE = "chevron7_stargate";

	private final StargateBlockEntity gate;
	private final AttachedComputerSet computers = new AttachedComputerSet();

	public StargatePeripheral(StargateBlockEntity gate)
	{
		this.gate = gate;
	}

	@Override
	public String getType()
	{
		return TYPE;
	}

	@Override
	public void attach(IComputerAccess computer)
	{
		computers.add(computer);
		gate.addListener(this);
	}

	@Override
	public void detach(IComputerAccess computer)
	{
		computers.remove(computer);
		if(!computers.hasComputers())
			gate.removeListener(this);
	}

	@Override
	public void gateEvent(String name, Object... args)
	{
		computers.forEach(computer -> {
			Object[] withName = new Object[args.length + 1];
			withName[0] = computer.getAttachmentName();
			System.arraycopy(args, 0, withName, 1, args.length);
			computer.queueEvent(name, withName);
		});
	}

	@Override
	public Object getTarget()
	{
		return gate;
	}

	@Override
	public boolean equals(@Nullable IPeripheral other)
	{
		return other instanceof StargatePeripheral peripheral && peripheral.gate == gate;
	}

	private float time()
	{
		return gate.getLevel() == null ? 0 : gate.getLevel().getGameTime();
	}

	//============================================================================================
	// about the gate
	//============================================================================================

	@LuaFunction(mainThread = true)
	public final String getStargateType()
	{
		return "chevron7:stargate";
	}

	@LuaFunction(mainThread = true)
	public final String getStargateVariant()
	{
		return "";
	}

	@LuaFunction(mainThread = true)
	public final int getStargateGeneration()
	{
		return 1;
	}

	@LuaFunction(mainThread = true)
	public final List<Integer> getLocalAddress()
	{
		return GateAddress.list(gate.getAddress());
	}

	//============================================================================================
	// state
	//============================================================================================

	@LuaFunction(mainThread = true)
	public final String getGateState()
	{
		return gate.getState().name().toLowerCase();
	}

	@LuaFunction(mainThread = true)
	public final int getChevronsEngaged()
	{
		return gate.getChevronsEngaged();
	}

	@LuaFunction(mainThread = true)
	public final boolean isStargateConnected()
	{
		return gate.getState().connected();
	}

	@LuaFunction(mainThread = true)
	public final boolean isStargateDialingOut()
	{
		StargateBlockEntity.State state = gate.getState();
		return state == StargateBlockEntity.State.DIALING || (state.connected() && gate.isOutgoing());
	}

	@LuaFunction(mainThread = true)
	public final boolean isWormholeOpen()
	{
		return gate.getState() == StargateBlockEntity.State.OPEN;
	}

	@LuaFunction(mainThread = true)
	public final int getOpenTime()
	{
		return gate.getOpenTicks();
	}

	@LuaFunction(mainThread = true)
	public final List<Integer> getConnectedAddress()
	{
		return gate.getState().connected() ? GateAddress.list(gate.getRemoteAddress()) : List.of();
	}

	@LuaFunction(mainThread = true)
	public final List<Integer> getDialedAddress()
	{
		StargateBlockEntity.State state = gate.getState();
		if(state == StargateBlockEntity.State.DIALING || (state.connected() && gate.isOutgoing()))
			return gate.getEncoded();
		return List.of();
	}

	@LuaFunction(mainThread = true)
	public final MethodResult getRecentFeedback()
	{
		return MethodResult.of(gate.getFeedback(), gate.getFeedbackText());
	}

	@LuaFunction(mainThread = true)
	public final double getRotationDegrees()
	{
		float angle = gate.ringAngle(time()) % 360.0F;
		return angle < 0 ? angle + 360.0F : angle;
	}

	@LuaFunction(mainThread = true)
	public final int getCurrentSymbol()
	{
		return gate.currentSymbol(time());
	}

	@LuaFunction(mainThread = true)
	public final boolean isCurrentSymbol(int symbol)
	{
		return !gate.isRotating() && gate.currentSymbol(time()) == symbol;
	}

	//============================================================================================
	// dialing
	//============================================================================================

	/** Turns the ring to the symbol and locks a chevron on it. Dial 0, the point of origin, last. */
	@LuaFunction(mainThread = true)
	public final int engageSymbol(int symbol)
	{
		return gate.engageSymbol(symbol, false);
	}

	/** Dials a whole address, e.g. {12, 5, 30, 21, 7, 1}. */
	@LuaFunction(mainThread = true)
	public final int dialAddress(Map<?, ?> address)
	{
		int[] symbols = new int[address.size()];
		for(int i = 0; i < symbols.length; i++)
		{
			Object value = address.get((double) (i + 1));
			if(!(value instanceof Number number))
				return gate.dial(new int[0]);
			symbols[i] = number.intValue();
		}
		if(symbols.length == GateAddress.LENGTH + 1 && symbols[GateAddress.LENGTH] == GateAddress.POINT_OF_ORIGIN)
			symbols = java.util.Arrays.copyOf(symbols, GateAddress.LENGTH);
		return gate.dial(symbols);
	}

	@LuaFunction(mainThread = true)
	public final boolean disconnectStargate()
	{
		return gate.disconnect(false) >= 0;
	}

	@LuaFunction(mainThread = true)
	public final boolean sendStargateMessage(String message)
	{
		return gate.sendMessage(message);
	}

	//============================================================================================
	// iris
	//============================================================================================

	@LuaFunction(mainThread = true)
	@Nullable
	public final String getIris()
	{
		return gate.hasIris() ? "chevron7:iris" : null;
	}

	@LuaFunction(mainThread = true)
	public final int getIrisProgressPercentage()
	{
		return Math.round(gate.irisProgress(time()) * 100);
	}

	@LuaFunction(mainThread = true)
	public final boolean closeIris()
	{
		return gate.setIris(true);
	}

	@LuaFunction(mainThread = true)
	public final boolean openIris()
	{
		return gate.setIris(false);
	}
}
