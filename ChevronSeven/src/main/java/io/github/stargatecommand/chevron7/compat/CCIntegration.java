package io.github.stargatecommand.chevron7.compat;

import dan200.computercraft.api.ForgeComputerCraftAPI;
import dan200.computercraft.api.peripheral.IPeripheral;
import io.github.stargatecommand.chevron7.Chevron7;
import io.github.stargatecommand.chevron7.GateFrameBlock;
import io.github.stargatecommand.chevron7.GateInterfaceBlock;
import io.github.stargatecommand.chevron7.StargateBlockEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraftforge.common.util.LazyOptional;

/**
 * Loaded only with CC: Tweaked: every block of the ring is a "chevron7_stargate" peripheral, and
 * so is a Gate Computer Interface touching the ring.
 */
public final class CCIntegration
{
	private CCIntegration() {}

	public static void init()
	{
		ForgeComputerCraftAPI.registerPeripheralProvider((level, pos, side) -> {
			BlockState state = level.getBlockState(pos);
			StargateBlockEntity gate = null;
			if(state.is(Chevron7.GATE_INTERFACE.get()))
				gate = GateInterfaceBlock.gateNextTo(level, pos);
			else
			{
				BlockPos core = state.is(Chevron7.GATE_FRAME.get()) ? GateFrameBlock.core(pos, state) : pos;
				if(level.getBlockEntity(core) instanceof StargateBlockEntity found)
					gate = found;
			}
			if(gate == null)
				return LazyOptional.empty();
			if(!(gate.peripheral instanceof StargatePeripheral))
				gate.peripheral = new StargatePeripheral(gate);
			IPeripheral peripheral = (IPeripheral) gate.peripheral;
			return LazyOptional.of(() -> peripheral);
		});
	}
}
