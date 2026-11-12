package io.github.stargatecommand.chevron7;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.chat.Component;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.Rotation;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BlockStateProperties;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.level.block.state.properties.DirectionProperty;
import net.minecraft.world.phys.BlockHitResult;

/**
 * The bottom middle block of the gate. Placing it builds the rest of the ring.
 */
public class StargateBlock extends BaseEntityBlock
{
	public static final DirectionProperty FACING = BlockStateProperties.HORIZONTAL_FACING;
	public static final BooleanProperty LIT = BlockStateProperties.LIT;

	public StargateBlock(Properties properties)
	{
		super(properties);
		registerDefaultState(stateDefinition.any().setValue(FACING, Direction.NORTH).setValue(LIT, false));
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder)
	{
		builder.add(FACING, LIT);
	}

	@Override
	public RenderShape getRenderShape(BlockState state)
	{
		return RenderShape.ENTITYBLOCK_ANIMATED;
	}

	@Override
	public BlockState rotate(BlockState state, Rotation rotation)
	{
		return state.setValue(FACING, rotation.rotate(state.getValue(FACING)));
	}

	@Nullable
	@Override
	public BlockState getStateForPlacement(BlockPlaceContext context)
	{
		Direction facing = context.getHorizontalDirection().getOpposite();
		Level level = context.getLevel();
		BlockPos core = context.getClickedPos();
		for(int[] cell : GateShape.FRAME)
		{
			if(!roomAt(level, GateShape.cell(core, facing, cell[0], cell[1])))
				return noRoom(context);
		}
		for(int[] cell : GateShape.INSIDE)
		{
			if(!roomAt(level, GateShape.cell(core, facing, cell[0], cell[1])))
				return noRoom(context);
		}
		return defaultBlockState().setValue(FACING, facing);
	}

	private static boolean roomAt(Level level, BlockPos pos)
	{
		return level.isInWorldBounds(pos) && level.getBlockState(pos).canBeReplaced();
	}

	@Nullable
	private static BlockState noRoom(BlockPlaceContext context)
	{
		if(context.getPlayer() != null && !context.getLevel().isClientSide())
			context.getPlayer().displayClientMessage(Component.translatable("message.chevron7.no_room"), true);
		return null;
	}

	@Override
	public void onPlace(BlockState state, Level level, BlockPos pos, BlockState oldState, boolean moving)
	{
		super.onPlace(state, level, pos, oldState, moving);
		if(level.isClientSide() || oldState.is(this))
			return;
		Direction facing = state.getValue(FACING);
		for(int part = 0; part < GateShape.FRAME.length; part++)
		{
			level.setBlock(GateShape.frameCell(pos, facing, part), Chevron7.GATE_FRAME.get().defaultBlockState()
					.setValue(GateFrameBlock.FACING, facing).setValue(GateFrameBlock.PART, part), Block.UPDATE_ALL);
		}
	}

	@Override
	public void onRemove(BlockState state, Level level, BlockPos pos, BlockState newState, boolean moving)
	{
		if(!state.is(newState.getBlock()))
		{
			if(level.getBlockEntity(pos) instanceof StargateBlockEntity gate)
				gate.onBroken();
			Direction facing = state.getValue(FACING);
			for(int part = 0; part < GateShape.FRAME.length; part++)
			{
				BlockPos cell = GateShape.frameCell(pos, facing, part);
				BlockState frame = level.getBlockState(cell);
				if(frame.is(Chevron7.GATE_FRAME.get()) && frame.getValue(GateFrameBlock.PART) == part && frame.getValue(GateFrameBlock.FACING) == facing)
					level.setBlock(cell, net.minecraft.world.level.block.Blocks.AIR.defaultBlockState(), Block.UPDATE_ALL);
			}
		}
		super.onRemove(state, level, pos, newState, moving);
	}

	@SuppressWarnings("deprecation")
	@Override
	public InteractionResult use(BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hit)
	{
		return showAddress(level, pos, player, player.getItemInHand(hand));
	}

	static InteractionResult showAddress(Level level, BlockPos core, Player player, ItemStack held)
	{
		if(held.getItem() instanceof IrisItem)
			return InteractionResult.PASS;
		if(!level.isClientSide() && level.getBlockEntity(core) instanceof StargateBlockEntity gate)
			player.displayClientMessage(Component.translatable("message.chevron7.address", GateAddress.format(gate.getAddress())), true);
		return InteractionResult.sidedSuccess(level.isClientSide());
	}

	@Override
	public boolean hasAnalogOutputSignal(BlockState state)
	{
		return true;
	}

	@Override
	public int getAnalogOutputSignal(BlockState state, Level level, BlockPos pos)
	{
		return level.getBlockEntity(pos) instanceof StargateBlockEntity gate ? gate.getChevronsEngaged() : 0;
	}

	@Override
	public ItemStack getCloneItemStack(BlockGetter level, BlockPos pos, BlockState state)
	{
		return new ItemStack(Chevron7.STARGATE_ITEM.get());
	}

	@Nullable
	@Override
	public BlockEntity newBlockEntity(BlockPos pos, BlockState state)
	{
		return new StargateBlockEntity(pos, state);
	}

	@Nullable
	@Override
	public <T extends BlockEntity> BlockEntityTicker<T> getTicker(Level level, BlockState state, BlockEntityType<T> type)
	{
		return level.isClientSide() ? null : createTickerHelper(type, Chevron7.STARGATE_ENTITY.get(), StargateBlockEntity::serverTick);
	}
}
