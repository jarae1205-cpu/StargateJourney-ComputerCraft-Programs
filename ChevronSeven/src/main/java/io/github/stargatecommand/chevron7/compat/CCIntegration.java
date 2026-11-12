package io.github.stargatecommand.chevron7.compat;

import dan200.computercraft.api.ForgeComputerCraftAPI;
import dan200.computercraft.api.peripheral.IPeripheral;
import io.github.stargatecommand.chevron7.Chevron7;
import io.github.stargatecommand.chevron7.GateFrameBlock;
import io.github.stargatecommand.chevron7.StargateBlockEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraftforge.common.util.LazyOptional;

/**
 * Loaded only with CC: Tweaked: every block of the ring is a "chevron7_stargate" peripheral.
 */
public final class CCIntegration
{
	private CCIntegration() {}

	public static void init()
	{
		ForgeComputerCraftAPI.registerPeripheralProvider((level, pos, side) -> {
			BlockPos core = pos;
			BlockState state = level.getBlockState(pos);
			if(state.is(Chevron7.GATE_FRAME.get()))
				core = GateFrameBlock.core(pos, state);
			if(level.getBlockEntity(core) instanceof StargateBlockEntity gate)
			{
				if(!(gate.peripheral instanceof StargatePeripheral))
					gate.peripheral = new StargatePeripheral(gate);
				IPeripheral peripheral = (IPeripheral) gate.peripheral;
				return LazyOptional.of(() -> peripheral);
			}
			return LazyOptional.empty();
		});
	}
}
