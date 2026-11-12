package io.github.stargatecommand.sgcaddon;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.level.BlockGetter;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.BaseEntityBlock;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.RenderShape;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.entity.BlockEntityTicker;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.StateDefinition;
import net.minecraft.world.level.block.state.properties.BooleanProperty;

/**
 * Watches the nearest gate: a redstone signal while its wormhole is open, and a
 * comparator signal equal to the number of chevrons locked.
 */
public class GateMonitorBlock extends BaseEntityBlock
{
	public static final BooleanProperty OPEN = BooleanProperty.create("open");
	public static final BooleanProperty INCOMING = BooleanProperty.create("incoming");

	public GateMonitorBlock(Properties properties)
	{
		super(properties);
		registerDefaultState(stateDefinition.any().setValue(OPEN, false).setValue(INCOMING, false));
	}

	@Override
	protected void createBlockStateDefinition(StateDefinition.Builder<Block, BlockState> builder)
	{
		builder.add(OPEN, INCOMING);
	}

	@Override
	public RenderShape getRenderShape(BlockState state)
	{
		return RenderShape.MODEL;
	}

	@Override
	public boolean isSignalSource(BlockState state)
	{
		return true;
	}

	@Override
	public int getSignal(BlockState state, BlockGetter level, BlockPos pos, Direction direction)
	{
		return state.getValue(OPEN) ? 15 : 0;
	}

	@Override
	public boolean hasAnalogOutputSignal(BlockState state)
	{
		return true;
	}

	@Override
	public int getAnalogOutputSignal(BlockState state, Level level, BlockPos pos)
	{
		return level.getBlockEntity(pos) instanceof GateMonitorBlockEntity monitor ? monitor.getChevrons() : 0;
	}

	@Nullable
	@Override
	public BlockEntity newBlockEntity(BlockPos pos, BlockState state)
	{
		return new GateMonitorBlockEntity(pos, state);
	}

	@Nullable
	@Override
	public <T extends BlockEntity> BlockEntityTicker<T> getTicker(Level level, BlockState state, BlockEntityType<T> type)
	{
		return level.isClientSide ? null : createTickerHelper(type, SGCAddon.GATE_MONITOR_ENTITY.get(), GateMonitorBlockEntity::serverTick);
	}
}
