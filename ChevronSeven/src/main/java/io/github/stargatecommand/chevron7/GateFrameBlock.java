package io.github.stargatecommand.chevron7;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.level.block.state.properties.DirectionProperty;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.phys.BlockHitResult;

/**
 * An invisible block of the ring. The stargate block draws the ring; these give it collision,
 * and breaking one breaks the whole gate.
 */
public class GateFrameBlock extends Block
{
	public static final DirectionProperty FACING = BlockStateProperties.HORIZONTAL_FACING;
	public static final IntegerProperty PART = IntegerProperty.create("part", 0, GateShape.FRAME.length - 1);
	public static final BooleanProperty LIT = BlockStateProperties.LIT;

	public GateFrameBlock(Properties properties)
	{
		super(properties);
		registerDefaultState(stateDefinition.any().setValue(FACING, Direction.NORTH).setValue(PART, 0).setValue(LIT, false));
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder)
	{
		builder.add(FACING, PART, LIT);
	}

	@Override
	public RenderShape getRenderShape(BlockState state)
	{
		return RenderShape.INVISIBLE;
	}

	public static BlockPos core(BlockPos pos, BlockState state)
	{
		return GateShape.coreOf(pos, state.getValue(FACING), state.getValue(PART));
	}

	@Override
	public void onRemove(BlockState state, Level level, BlockPos pos, BlockState newState, boolean moving)
	{
		if(!state.is(newState.getBlock()) && !level.isClientSide())
		{
			BlockPos core = core(pos, state);
			BlockState coreState = level.getBlockState(core);
			if(coreState.is(Chevron7.STARGATE.get()) && coreState.getValue(StargateBlock.FACING) == state.getValue(FACING))
				level.destroyBlock(core, true);
		}
		super.onRemove(state, level, pos, newState, moving);
	}

	@SuppressWarnings("deprecation")
	@Override
	public InteractionResult use(BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hit)
	{
		return StargateBlock.showAddress(level, core(pos, state), player, player.getItemInHand(hand));
	}

	@Override
	public ItemStack getCloneItemStack(BlockGetter level, BlockPos pos, BlockState state)
	{
		return new ItemStack(Chevron7.STARGATE_ITEM.get());
	}

	@Override
	public float getDestroyProgress(BlockState state, Player player, BlockGetter level, BlockPos pos)
	{
		// as hard to break as the stargate block itself
		BlockState core = level.getBlockState(core(pos, state));
		return core.is(Chevron7.STARGATE.get()) ? core.getDestroyProgress(player, level, core(pos, state)) : super.getDestroyProgress(state, player, level, pos);
	}
}
