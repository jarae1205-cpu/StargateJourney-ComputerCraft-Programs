package io.github.stargatecommand.chevron7.compat;

import dan200.computercraft.api.ForgeComputerCraftAPI;
import dan200.computercraft.api.peripheral.IPeripheral;
import io.github.stargatecommand.chevron7.Chevron7;
import io.github.stargatecommand.chevron7.GateFrameBlock;
import io.github.stargatecommand.chevron7.SGInterfaceBlockEntity;
import io.github.stargatecommand.chevron7.StargateBlockEntity;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraftforge.common.util.LazyOptional;

/**
 * Loaded only with CC: Tweaked: every block of the ring is a "chevron7_stargate" peripheral,
 * and the SG interface is a "stargate" peripheral that speaks SGCraft's language.
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
			if(level.getBlockEntity(pos) instanceof SGInterfaceBlockEntity sgInterface)
			{
				if(!(sgInterface.peripheral instanceof SGInterfacePeripheral))
					sgInterface.peripheral = new SGInterfacePeripheral(sgInterface);
				IPeripheral peripheral = (IPeripheral) sgInterface.peripheral;
				return LazyOptional.of(() -> peripheral);
			}
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
