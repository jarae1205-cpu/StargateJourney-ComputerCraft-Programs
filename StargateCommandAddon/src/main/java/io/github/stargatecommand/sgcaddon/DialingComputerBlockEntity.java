package io.github.stargatecommand.sgcaddon;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

/**
 * Keeps the dialing computer's screen in step with the nearest gate. The screen itself
 * is the block's model: the block state carries the gate's mode and its chevron count.
 */
public class DialingComputerBlockEntity extends BlockEntity
{
	/** How far the computer looks for a gate. */
	public static final int RANGE = 16;

	private int ticks;

	public DialingComputerBlockEntity(BlockPos pos, BlockState state)
	{
		super(SGCAddon.DIALING_COMPUTER_ENTITY.get(), pos, state);
	}

	public static void serverTick(Level level, BlockPos pos, BlockState state, DialingComputerBlockEntity computer)
	{
		// four times a second keeps up with a chevron a second
		if(++computer.ticks < 5)
			return;
		computer.ticks = 0;

		GateWatcher.Status gate = GateWatcher.nearest(level, pos, RANGE);
		DialingComputerBlock.Mode mode = DialingComputerBlock.Mode.of(gate);
		int chevrons = gate == null ? 0 : Math.max(0, Math.min(9, gate.chevrons()));
		if(mode != state.getValue(DialingComputerBlock.MODE) || chevrons != state.getValue(DialingComputerBlock.CHEVRONS))
			level.setBlock(pos, state.setValue(DialingComputerBlock.MODE, mode).setValue(DialingComputerBlock.CHEVRONS, chevrons), Block.UPDATE_CLIENTS);
	}
}
