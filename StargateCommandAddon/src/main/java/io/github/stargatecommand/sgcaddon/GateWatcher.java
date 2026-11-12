package io.github.stargatecommand.sgcaddon;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.chunk.LevelChunk;
import net.povstalec.sgjourney.common.block_entities.stargate.AbstractStargateEntity;

/**
 * Finds the Stargate Journey gate closest to a block and reads its state.
 */
public final class GateWatcher
{
	private GateWatcher() {}

	/**
	 * @param connected    a wormhole connection exists (being formed or open)
	 * @param dialingOut   this gate made the connection
	 * @param chevrons     chevrons locked
	 * @param wormholeOpen the event horizon is open
	 */
	public record Status(boolean connected, boolean dialingOut, int chevrons, boolean wormholeOpen)
	{
		/** Another gate is dialing in, or its wormhole is open here. */
		public boolean incoming()
		{
			return connected && !dialingOut;
		}

		/** Another gate is dialing in and the wormhole has not opened yet. */
		public boolean activating()
		{
			return incoming() && !wormholeOpen;
		}
	}

	@Nullable
	public static Status nearest(Level level, BlockPos pos, int radius)
	{
		AbstractStargateEntity<?> best = null;
		double bestDistance = (double) radius * radius;
		int minChunkX = (pos.getX() - radius) >> 4;
		int maxChunkX = (pos.getX() + radius) >> 4;
		int minChunkZ = (pos.getZ() - radius) >> 4;
		int maxChunkZ = (pos.getZ() + radius) >> 4;
		for(int chunkX = minChunkX; chunkX <= maxChunkX; chunkX++)
		{
			for(int chunkZ = minChunkZ; chunkZ <= maxChunkZ; chunkZ++)
			{
				if(!level.hasChunk(chunkX, chunkZ))
					continue;
				LevelChunk chunk = level.getChunk(chunkX, chunkZ);
				for(BlockEntity blockEntity : chunk.getBlockEntities().values())
				{
					if(blockEntity instanceof AbstractStargateEntity<?> stargate)
					{
						double distance = blockEntity.getBlockPos().distSqr(pos);
						if(distance <= bestDistance)
						{
							best = stargate;
							bestDistance = distance;
						}
					}
				}
			}
		}
		if(best == null)
			return null;
		return new Status(best.isConnected(), best.isDialingOut(), best.getChevronsEngaged(), best.isWormholeOpen());
	}
}
