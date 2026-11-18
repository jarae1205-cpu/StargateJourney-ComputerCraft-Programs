package io.github.stargatecommand.chevron7;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.block.EntityBlock;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.HorizontalDirectionalBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BooleanProperty;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.fml.DistExecutor;

/**
 * Dial Home Device: dials the nearest gate within 16 blocks. The block model is its pedestal; the
 * round top with its keys and dome is drawn by the client from the block entity.
 */
public class DHDBlock extends HorizontalDirectionalBlock implements EntityBlock
{
	public static final int RANGE = 16;
	/** The Carter Addon Pack's orange DHD with a blue dome; otherwise the dark one with a red dome, as in JSG and the show. */
	public static final BooleanProperty CAP = BooleanProperty.create("cap");
	private static final VoxelShape SHAPE = Shapes.or(Block.box(1, 0, 1, 15, 10, 15), Block.box(0, 10, 0, 16, 16, 16));

	public DHDBlock(Properties properties)
	{
		super(properties);
		registerDefaultState(stateDefinition.any().setValue(FACING, Direction.NORTH).setValue(CAP, false));
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder)
	{
		builder.add(FACING, CAP);
	}

	@Override
	public BlockState getStateForPlacement(BlockPlaceContext context)
	{
		return defaultBlockState().setValue(FACING, context.getHorizontalDirection().getOpposite());
	}

	@SuppressWarnings("deprecation")
	@Override
	public VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context)
	{
		return SHAPE;
	}

	@Override
	public BlockEntity newBlockEntity(BlockPos pos, BlockState state)
	{
		return new DHDBlockEntity(pos, state);
	}

	/** DHDs from before 1.3.0 have no block entity yet; a random tick makes one, so their top appears. */
	@Override
	public boolean isRandomlyTicking(BlockState state)
	{
		return true;
	}

	@SuppressWarnings("deprecation")
	@Override
	public void randomTick(BlockState state, ServerLevel level, BlockPos pos, RandomSource random)
	{
		if(level.getChunkAt(pos).getBlockEntity(pos, net.minecraft.world.level.chunk.LevelChunk.EntityCreationType.CHECK) == null)
		{
			level.getBlockEntity(pos);
			level.sendBlockUpdated(pos, state, state, Block.UPDATE_CLIENTS);
		}
	}

	@SuppressWarnings("deprecation")
	@Override
	public InteractionResult use(BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hit)
	{
		// a Look Crystal swaps the DHD's style instead (LookCrystalItem)
		if(player.getItemInHand(hand).getItem() instanceof LookCrystalItem)
			return InteractionResult.PASS;
		if(level.isClientSide())
			DistExecutor.unsafeRunWhenOn(Dist.CLIENT, () -> () -> io.github.stargatecommand.chevron7.client.ClientHooks.openDhd(pos));
		return InteractionResult.sidedSuccess(level.isClientSide());
	}
}
