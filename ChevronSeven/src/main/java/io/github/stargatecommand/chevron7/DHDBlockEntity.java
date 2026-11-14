package io.github.stargatecommand.chevron7;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.AABB;

/**
 * The DHD's block entity. It stores nothing; it lets the client draw the round top of the DHD,
 * whose keys light up as its gate dials, and remembers which gate that is.
 */
public class DHDBlockEntity extends BlockEntity
{
	@Nullable
	private BlockPos gatePos;
	private long nextLookup;

	public DHDBlockEntity(BlockPos pos, BlockState state)
	{
		super(Chevron7.DHD_ENTITY.get(), pos, state);
	}

	/** The gate this DHD dials (the nearest one), looked up again every two seconds. */
	@Nullable
	public StargateBlockEntity gate()
	{
		if(level == null)
			return null;
		long now = level.getGameTime();
		if(now >= nextLookup)
		{
			nextLookup = now + 40;
			StargateBlockEntity gate = GateShape.nearestGate(level, worldPosition, DHDBlock.RANGE);
			gatePos = gate == null ? null : gate.getBlockPos();
		}
		if(gatePos != null && level.getBlockEntity(gatePos) instanceof StargateBlockEntity gate && !gate.isRemoved())
			return gate;
		return null;
	}

	@Override
	public AABB getRenderBoundingBox()
	{
		// the top reaches past the block on every side
		return new AABB(worldPosition).inflate(1.0, 1.0, 1.0);
	}
}
