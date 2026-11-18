package io.github.stargatecommand.chevron7;

import java.util.ArrayList;
import java.util.List;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.chunk.LevelChunk;
import net.minecraft.world.phys.Vec3;

/**
 * The gate is a ring seven blocks across. The stargate block sits at the bottom middle,
 * at (0, 0); x runs to the right as you face the gate, y runs up. The ring's centre is (0, 3).
 */
public final class GateShape
{
	private GateShape() {}

	/** Frame cells {x, y}, without the stargate block itself. Index = the frame block's PART. */
	public static final int[][] FRAME;
	/** Cells inside the ring, where the event horizon forms. */
	public static final int[][] INSIDE;

	/**
	 * The frame cells behind the nine chevrons, which the renderer draws every 40 degrees from
	 * the top: the frame cell nearest each one. A gate built from blocks has its Chevron Blocks
	 * here and Ring Blocks in the other 14 cells. The pattern is the same mirrored, so it doesn't
	 * matter which way the gate faces.
	 */
	public static final int[][] CHEVRON_CELLS = {{0, 6}, {2, 5}, {3, 4}, {3, 1}, {1, 0}, {-1, 0}, {-3, 1}, {-3, 4}, {-2, 5}};

	public static final double CENTER_HEIGHT = 3.5;
	public static final double HORIZON_RADIUS = 2.45;

	static
	{
		List<int[]> frame = new ArrayList<>();
		List<int[]> inside = new ArrayList<>();
		for(int y = 0; y < 7; y++)
		{
			for(int x = -3; x <= 3; x++)
			{
				double distance = Math.sqrt(x * x + (y - 3) * (y - 3));
				if(distance < 2.6)
					inside.add(new int[] {x, y});
				else if(distance <= 3.65 && !(x == 0 && y == 0))
					frame.add(new int[] {x, y});
			}
		}
		FRAME = frame.toArray(new int[0][]);
		INSIDE = inside.toArray(new int[0][]);
	}

	/** Whether a frame cell (by its PART index) holds a chevron. */
	public static boolean isChevron(int part)
	{
		int[] cell = FRAME[part];
		for(int[] chevron : CHEVRON_CELLS)
		{
			if(chevron[0] == cell[0] && chevron[1] == cell[1])
				return true;
		}
		return false;
	}

	/** To the right of someone looking at the front of the gate. */
	public static Direction right(Direction facing)
	{
		return facing.getCounterClockWise();
	}

	public static BlockPos cell(BlockPos core, Direction facing, int x, int y)
	{
		return core.relative(right(facing), x).above(y);
	}

	public static BlockPos frameCell(BlockPos core, Direction facing, int part)
	{
		return cell(core, facing, FRAME[part][0], FRAME[part][1]);
	}

	public static BlockPos coreOf(BlockPos frame, Direction facing, int part)
	{
		return frame.relative(right(facing), -FRAME[part][0]).below(FRAME[part][1]);
	}

	public static Vec3 center(BlockPos core)
	{
		return new Vec3(core.getX() + 0.5, core.getY() + CENTER_HEIGHT, core.getZ() + 0.5);
	}

	public static Vec3 normal(Direction facing)
	{
		return new Vec3(facing.getStepX(), 0, facing.getStepZ());
	}

	/**
	 * Every gate within the radius among the loaded chunks, in a steady order (west to east,
	 * then north to south) so a DHD's list doesn't jump around.
	 */
	public static List<StargateBlockEntity> gatesNear(Level level, BlockPos pos, int radius)
	{
		List<StargateBlockEntity> gates = new ArrayList<>();
		double max = (double) radius * radius;
		for(int chunkX = (pos.getX() - radius) >> 4; chunkX <= (pos.getX() + radius) >> 4; chunkX++)
		{
			for(int chunkZ = (pos.getZ() - radius) >> 4; chunkZ <= (pos.getZ() + radius) >> 4; chunkZ++)
			{
				if(!level.hasChunk(chunkX, chunkZ))
					continue;
				for(BlockEntity blockEntity : level.getChunk(chunkX, chunkZ).getBlockEntities().values())
				{
					if(blockEntity instanceof StargateBlockEntity gate && !gate.isRemoved() && blockEntity.getBlockPos().distSqr(pos) <= max)
						gates.add(gate);
				}
			}
		}
		gates.sort((a, b) -> a.getBlockPos().getX() != b.getBlockPos().getX()
				? Integer.compare(a.getBlockPos().getX(), b.getBlockPos().getX())
				: Integer.compare(a.getBlockPos().getZ(), b.getBlockPos().getZ()));
		return gates;
	}

	/** The gate at a position if it is within the radius, otherwise the nearest one. */
	@Nullable
	public static StargateBlockEntity chosenGate(Level level, BlockPos pos, int radius, @Nullable BlockPos choice)
	{
		if(choice != null && choice.distSqr(pos) <= (double) radius * radius && level.isLoaded(choice)
				&& level.getBlockEntity(choice) instanceof StargateBlockEntity gate && !gate.isRemoved())
			return gate;
		return nearestGate(level, pos, radius);
	}

	/** The nearest gate to a position, among the loaded chunks. */
	@Nullable
	public static StargateBlockEntity nearestGate(Level level, BlockPos pos, int radius)
	{
		StargateBlockEntity best = null;
		double bestDistance = (double) radius * radius;
		for(int chunkX = (pos.getX() - radius) >> 4; chunkX <= (pos.getX() + radius) >> 4; chunkX++)
		{
			for(int chunkZ = (pos.getZ() - radius) >> 4; chunkZ <= (pos.getZ() + radius) >> 4; chunkZ++)
			{
				if(!level.hasChunk(chunkX, chunkZ))
					continue;
				LevelChunk chunk = level.getChunk(chunkX, chunkZ);
				for(BlockEntity blockEntity : chunk.getBlockEntities().values())
				{
					if(blockEntity instanceof StargateBlockEntity gate && !gate.isRemoved())
					{
						double distance = blockEntity.getBlockPos().distSqr(pos);
						if(distance <= bestDistance)
						{
							best = gate;
							bestDistance = distance;
						}
					}
				}
			}
		}
		return best;
	}
}
