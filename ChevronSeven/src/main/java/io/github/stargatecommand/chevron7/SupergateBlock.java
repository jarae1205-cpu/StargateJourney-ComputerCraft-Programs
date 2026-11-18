package io.github.stargatecommand.chevron7;

import net.minecraft.core.BlockPos;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;

/**
 * An Ori supergate: a gate SCALE times the size of the others, drawn as a ring of separate
 * segments. Only this block, at the bottom middle of the ring, is solid; the ring itself is
 * drawn by the gate's renderer and has no frame blocks. It dials and travels like any gate.
 */
public class SupergateBlock extends StargateBlock
{
	public static final int SCALE = 4;

	public SupergateBlock(Properties properties)
	{
		super(properties);
	}

	@Override
	public void onPlace(BlockState state, Level level, BlockPos pos, BlockState oldState, boolean moving)
	{
		// no frame blocks: the ring is too big for them
	}

	@Override
	public ItemStack getCloneItemStack(BlockGetter level, BlockPos pos, BlockState state)
	{
		return ItemStack.EMPTY;
	}
}
