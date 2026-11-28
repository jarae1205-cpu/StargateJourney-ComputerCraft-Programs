package io.github.stargatecommand.sgcaddon;

import java.util.EnumMap;
import java.util.Map;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.network.chat.Component;
import net.minecraft.util.StringRepresentable;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResult;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.context.BlockPlaceContext;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.HorizontalDirectionalBlock;
import net.minecraft.world.level.block.Mirror;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.Rotation;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.DirectionProperty;
import net.minecraft.world.level.block.state.properties.EnumProperty;
import net.minecraft.world.level.block.state.properties.IntegerProperty;
import net.minecraft.world.level.pathfinder.PathComputationType;
import net.minecraft.world.phys.BlockHitResult;
import net.minecraft.world.phys.shapes.CollisionContext;
import net.minecraft.world.phys.shapes.Shapes;
import net.minecraft.world.phys.shapes.VoxelShape;

/**
 * The SGC's dialing computer on a stand. Its screen shows the nearest gate in teal lines
 * and fills a numbered box for each chevron as the gate dials, like the computer in the
 * SGC control room. Using it tells the player the gate's state.
 */
public class DialingComputerBlock extends BaseEntityBlock
{
	/** What the screen shows. */
	public enum Mode implements StringRepresentable
	{
		/** No stargate within range. */
		NONE("none"),
		IDLE("idle"),
		/** This gate is dialing out, or its wormhole is forming. */
		DIALING("dialing"),
		/** This gate dialed out and its wormhole is open. */
		OPEN("open"),
		/** Another gate is dialing in. */
		INCOMING("incoming"),
		/** Another gate dialed in and the wormhole is open. */
		INCOMING_OPEN("incoming_open");

		private final String name;

		Mode(String name)
		{
			this.name = name;
		}

		@Override
		public String getSerializedName()
		{
			return name;
		}

		public static Mode of(@Nullable GateWatcher.Status gate)
		{
			if(gate == null)
				return NONE;
			if(gate.incoming())
				return gate.wormholeOpen() ? INCOMING_OPEN : INCOMING;
			if(gate.wormholeOpen())
				return OPEN;
			if(gate.connected() || gate.chevrons() > 0)
				return DIALING;
			return IDLE;
		}
	}

	public static final DirectionProperty FACING = HorizontalDirectionalBlock.FACING;
	public static final EnumProperty<Mode> MODE = EnumProperty.create("mode", Mode.class);
	public static final IntegerProperty CHEVRONS = IntegerProperty.create("chevrons", 0, 9);

	// the stand, the desk and the screen leaning back, for a computer whose screen faces north
	private static final double[][] BOXES = {
			{1, 0, 1, 15, 2, 15},     // base plate
			{4, 2, 4, 12, 10, 12},    // column
			{1, 10, 2, 15, 13, 14},   // desk
			{1, 13, 7, 15, 18, 12.5}, // screen, lower half
			{1, 18, 9, 15, 23.25, 14.5}, // screen, upper half (it leans back)
	};
	private static final Map<Direction, VoxelShape> SHAPES = new EnumMap<>(Direction.class);
	static
	{
		for(Direction facing : Direction.Plane.HORIZONTAL)
		{
			VoxelShape shape = Shapes.empty();
			for(double[] b : BOXES)
				shape = Shapes.or(shape, rotated(b, facing));
			SHAPES.put(facing, shape.optimize());
		}
	}

	public DialingComputerBlock(Properties properties)
	{
		super(properties);
		registerDefaultState(stateDefinition.any().setValue(FACING, Direction.NORTH).setValue(MODE, Mode.NONE).setValue(CHEVRONS, 0));
	}

	/** A box of the north-facing computer, turned to face the given way. */
	private static VoxelShape rotated(double[] b, Direction facing)
	{
		double x1 = b[0], z1 = b[2], x2 = b[3], z2 = b[5];
		return switch(facing)
		{
			case SOUTH -> Block.box(16 - x2, b[1], 16 - z2, 16 - x1, b[4], 16 - z1);
			case WEST -> Block.box(z1, b[1], 16 - x2, z2, b[4], 16 - x1);
			case EAST -> Block.box(16 - z2, b[1], x1, 16 - z1, b[4], x2);
			default -> Block.box(x1, b[1], z1, x2, b[4], z2);
		};
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder)
	{
		builder.add(FACING, MODE, CHEVRONS);
	}

	@Override
	public BlockState getStateForPlacement(BlockPlaceContext context)
	{
		// the screen faces the player who placed it
		return defaultBlockState().setValue(FACING, context.getHorizontalDirection().getOpposite());
	}

	@Override
	public BlockState rotate(BlockState state, Rotation rotation)
	{
		return state.setValue(FACING, rotation.rotate(state.getValue(FACING)));
	}

	@Override
	@SuppressWarnings("deprecation")
	public BlockState mirror(BlockState state, Mirror mirror)
	{
		return state.rotate(mirror.getRotation(state.getValue(FACING)));
	}

	@Override
	public VoxelShape getShape(BlockState state, BlockGetter level, BlockPos pos, CollisionContext context)
	{
		return SHAPES.get(state.getValue(FACING));
	}

	@Override
	public boolean useShapeForLightOcclusion(BlockState state)
	{
		return true;
	}

	@Override
	public boolean isPathfindable(BlockState state, BlockGetter level, BlockPos pos, PathComputationType type)
	{
		return false;
	}

	@Override
	public RenderShape getRenderShape(BlockState state)
	{
		return RenderShape.MODEL;
	}

	@Override
	public InteractionResult use(BlockState state, Level level, BlockPos pos, Player player, InteractionHand hand, BlockHitResult hit)
	{
		if(!level.isClientSide)
			player.displayClientMessage(describe(GateWatcher.nearest(level, pos, DialingComputerBlockEntity.RANGE)), true);
		return InteractionResult.sidedSuccess(level.isClientSide);
	}

	/** The line shown above the hotbar when the computer is used. */
	static Component describe(@Nullable GateWatcher.Status gate)
	{
		String key = "block.sgcaddon.dialing_computer." + Mode.of(gate).getSerializedName();
		int chevrons = gate == null ? 0 : gate.chevrons();
		if(gate != null && Mode.of(gate) == Mode.DIALING)
		{
			if(gate.connected())
				key += ".locked";
			else if(chevrons == 0)
				key += ".start";
		}
		return Component.translatable(key, chevrons, DialingComputerBlockEntity.RANGE);
	}

	@Nullable
	@Override
	public BlockEntity newBlockEntity(BlockPos pos, BlockState state)
	{
		return new DialingComputerBlockEntity(pos, state);
	}

	@Nullable
	@Override
	public <T extends BlockEntity> BlockEntityTicker<T> getTicker(Level level, BlockState state, BlockEntityType<T> type)
	{
		return level.isClientSide ? null : createTickerHelper(type, SGCAddon.DIALING_COMPUTER_ENTITY.get(), DialingComputerBlockEntity::serverTick);
	}
}
