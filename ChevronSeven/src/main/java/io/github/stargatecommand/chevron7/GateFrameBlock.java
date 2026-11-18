package io.github.stargatecommand.chevron7;

import java.util.List;

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
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.storage.loot.LootParams;
import net.minecraft.world.phys.BlockHitResult;

/**
 * An invisible block of the ring. The stargate block draws the ring; these give it collision,
 * and breaking one breaks the whole gate. In a gate built from blocks (BUILT), breaking one drops
 * its Ring or Chevron Block and turns the rest of the gate back into blocks.
 */
public class GateFrameBlock extends Block
{
	public static final DirectionProperty FACING = BlockStateProperties.HORIZONTAL_FACING;
	public static final IntegerProperty PART = IntegerProperty.create("part", 0, GateShape.FRAME.length - 1);
	public static final BooleanProperty LIT = BlockStateProperties.LIT;
	public static final BooleanProperty BUILT = BooleanProperty.create("built");

	public GateFrameBlock(Properties properties)
	{
		super(properties);
		registerDefaultState(stateDefinition.any().setValue(FACING, Direction.NORTH).setValue(PART, 0).setValue(LIT, false).setValue(BUILT, false));
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder)
	{
		builder.add(FACING, PART, LIT, BUILT);
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
			if(coreState.getBlock() instanceof StargateBlock && coreState.getValue(StargateBlock.FACING) == state.getValue(FACING))
			{
				if(level instanceof ServerLevel server && level.getBlockEntity(core) instanceof StargateBlockEntity gate && gate.isBuiltFromParts())
					GateAssembly.unform(server, core);
				else
					level.destroyBlock(core, true);
			}
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
		if(state.getValue(BUILT))
			return GateAssembly.partItem(state.getValue(PART));
		BlockState core = level.getBlockState(core(pos, state));
		return new ItemStack(core.getBlock() instanceof StargateBlock ? core.getBlock() : Chevron7.STARGATE.get());
	}

	/** Nothing, except in a gate built from blocks: the Ring or Chevron Block that was here. */
	@SuppressWarnings("deprecation")
	@Override
	public List<ItemStack> getDrops(BlockState state, LootParams.Builder builder)
	{
		return state.getValue(BUILT) ? List.of(GateAssembly.partItem(state.getValue(PART))) : List.of();
	}

	@Override
	public float getDestroyProgress(BlockState state, Player player, BlockGetter level, BlockPos pos)
	{
		// as hard to break as the stargate block itself
		BlockState core = level.getBlockState(core(pos, state));
		return core.getBlock() instanceof StargateBlock ? core.getDestroyProgress(player, level, core(pos, state)) : super.getDestroyProgress(state, player, level, pos);
	}
}
