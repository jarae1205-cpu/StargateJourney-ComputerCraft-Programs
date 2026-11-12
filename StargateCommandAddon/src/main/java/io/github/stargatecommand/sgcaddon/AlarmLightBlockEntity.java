package io.github.stargatecommand.sgcaddon;

import net.minecraft.core.BlockPos;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.sounds.SoundSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

public class AlarmLightBlockEntity extends BlockEntity
{
	/** How far the light looks for a gate. */
	public static final int RANGE = 16;

	private int ticks;
	private int beeps;

	public AlarmLightBlockEntity(BlockPos pos, BlockState state)
	{
		super(SGCAddon.ALARM_LIGHT_ENTITY.get(), pos, state);
	}

	public static void serverTick(Level level, BlockPos pos, BlockState state, AlarmLightBlockEntity light)
	{
		// twice a second is plenty
		if(++light.ticks < 10)
			return;
		light.ticks = 0;

		GateWatcher.Status gate = GateWatcher.nearest(level, pos, RANGE);
		boolean alarm = level.hasNeighborSignal(pos) || (gate != null && gate.incoming());
		if(alarm != state.getValue(AlarmLightBlock.LIT))
			level.setBlock(pos, state.setValue(AlarmLightBlock.LIT, alarm), BLOCK_UPDATE_ALL);

		// the klaxon sounds while the wormhole is forming ("unscheduled offworld activation")
		if(gate != null && gate.activating())
		{
			light.beeps++;
			level.playSound(null, pos, SoundEvents.NOTE_BLOCK_DIDGERIDOO.value(), SoundSource.BLOCKS, 2.0F, light.beeps % 2 == 0 ? 0.6F : 0.8F);
		}
		else
			light.beeps = 0;
	}

	private static final int BLOCK_UPDATE_ALL = 3;
}
