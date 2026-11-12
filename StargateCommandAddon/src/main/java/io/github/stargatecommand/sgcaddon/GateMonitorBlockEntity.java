package io.github.stargatecommand.sgcaddon;

import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

public class GateMonitorBlockEntity extends BlockEntity
{
	public static final int RANGE = 16;

	private int ticks;
	private int chevrons;

	public GateMonitorBlockEntity(BlockPos pos, BlockState state)
	{
		super(SGCAddon.GATE_MONITOR_ENTITY.get(), pos, state);
	}

	public int getChevrons()
	{
		return chevrons;
	}

	public static void serverTick(Level level, BlockPos pos, BlockState state, GateMonitorBlockEntity monitor)
	{
		if(++monitor.ticks < 5)
			return;
		monitor.ticks = 0;

		GateWatcher.Status gate = GateWatcher.nearest(level, pos, RANGE);
		boolean open = gate != null && gate.wormholeOpen();
		boolean incoming = gate != null && gate.incoming();
		int chevrons = gate == null ? 0 : Math.min(15, gate.chevrons());

		if(open != state.getValue(GateMonitorBlock.OPEN) || incoming != state.getValue(GateMonitorBlock.INCOMING))
			level.setBlock(pos, state.setValue(GateMonitorBlock.OPEN, open).setValue(GateMonitorBlock.INCOMING, incoming), 3);
		if(chevrons != monitor.chevrons)
		{
			monitor.chevrons = chevrons;
			monitor.setChanged();
			level.updateNeighbourForOutputSignal(pos, state.getBlock());
		}
	}

	@Override
	protected void saveAdditional(CompoundTag tag)
	{
		super.saveAdditional(tag);
		tag.putInt("Chevrons", chevrons);
	}

	@Override
	public void load(CompoundTag tag)
	{
		super.load(tag);
		chevrons = tag.getInt("Chevrons");
	}
}
