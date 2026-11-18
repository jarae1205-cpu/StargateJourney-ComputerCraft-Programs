package io.github.stargatecommand.chevron7;

import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;

/**
 * A Stargate Ring Block or Chevron Block: what a gate is built from, SGCraft style. Around a
 * Stargate Base Block, 14 Ring Blocks and 9 Chevron Blocks become a gate.
 */
public class GatePartBlock extends Block
{
	private final boolean chevron;

	public GatePartBlock(Properties properties, boolean chevron)
	{
		super(properties);
		this.chevron = chevron;
	}

	public boolean isChevron()
	{
		return chevron;
	}

	@Override
	public void onPlace(BlockState state, Level level, BlockPos pos, BlockState oldState, boolean moving)
	{
		super.onPlace(state, level, pos, oldState, moving);
		// look for a base next tick, once whoever placed the block has finished with it
		if(!level.isClientSide() && !oldState.is(this))
			level.scheduleTick(pos, this, 1);
	}

	@SuppressWarnings("deprecation")
	@Override
	public void tick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random)
	{
		GateAssembly.formAround(level, pos);
	}
}
