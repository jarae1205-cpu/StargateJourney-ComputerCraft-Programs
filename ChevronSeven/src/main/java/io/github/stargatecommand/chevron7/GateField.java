package io.github.stargatecommand.chevron7;

import java.util.ArrayList;
import java.util.List;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.tags.BlockTags;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.levelgen.Heightmap;

/**
 * A gate field: several gates on an arc around a clearing, each at the end of a dirt path,
 * with one DHD in the middle that can dial from any of them.
 */
public final class GateField
{
	private GateField() {}

	public static final int RADIUS = 13;
	public static final int MAX_GATES = 7;

	/** Where the gates of a field go, and which way each one faces (towards the middle). */
	public record Site(BlockPos core, Direction facing) {}

	/**
	 * Plans the gates on an arc of RADIUS around the centre, opening towards {@code opens}.
	 * The heights are left at the centre's; {@link #build} puts each gate on the ground.
	 */
	public static List<Site> plan(BlockPos center, Direction opens, int count)
	{
		List<Site> sites = new ArrayList<>();
		double spread = Math.toRadians(Math.min(150, 30 * (count - 1)));
		for(int i = 0; i < count; i++)
		{
			double angle = count == 1 ? 0 : -spread / 2 + spread * i / (count - 1);
			double ox = opens.getStepX(), oz = opens.getStepZ();
			double vx = ox * Math.cos(angle) - oz * Math.sin(angle);
			double vz = ox * Math.sin(angle) + oz * Math.cos(angle);
			BlockPos core = center.offset((int) Math.round(vx * RADIUS), 0, (int) Math.round(vz * RADIUS));
			// gates only face the four directions: the one closest to looking back at the middle
			Direction facing = Direction.getNearest(-vx, 0, -vz);
			sites.add(new Site(core, facing));
		}
		return sites;
	}

	/** The lowest and highest ground under the field, to see if it is flat enough. */
	public static int[] groundRange(LevelAccessor level, BlockPos center, Direction opens, int count, Heightmap.Types heightmap)
	{
		int min = level.getHeight(heightmap, center.getX(), center.getZ());
		int max = min;
		for(Site site : plan(center, opens, count))
		{
			int y = level.getHeight(heightmap, site.core().getX(), site.core().getZ());
			min = Math.min(min, y);
			max = Math.max(max, y);
		}
		return new int[] {min, max};
	}

	/**
	 * Builds the field: clears a space for each gate, gives it ground to stand on, places it,
	 * lays the paths and puts the DHD in the middle. Works in a live level and during world generation.
	 * @return where the gates were placed
	 */
	public static List<BlockPos> build(LevelAccessor level, BlockPos centerColumn, Direction opens, int count, Heightmap.Types heightmap)
	{
		count = Math.max(1, Math.min(MAX_GATES, count));
		int flags = Block.UPDATE_CLIENTS;
		int centerY = level.getHeight(heightmap, centerColumn.getX(), centerColumn.getZ());
		BlockPos center = new BlockPos(centerColumn.getX(), centerY, centerColumn.getZ());

		List<BlockPos> gates = new ArrayList<>();
		for(Site site : plan(center, opens, count))
		{
			int y = level.getHeight(heightmap, site.core().getX(), site.core().getZ());
			BlockPos core = new BlockPos(site.core().getX(), y, site.core().getZ());
			Direction facing = site.facing();
			Direction right = GateShape.right(facing);

			// clear the gate's plane and a strip in front and behind, then give it ground
			for(int x = -3; x <= 3; x++)
			{
				for(int depth = -1; depth <= 1; depth++)
				{
					for(int up = 0; up < 8; up++)
						level.setBlock(core.relative(right, x).relative(facing, depth).above(up), Blocks.AIR.defaultBlockState(), flags);
					fillDown(level, core.relative(right, x).relative(facing, depth).below(), flags);
				}
			}

			BlockState coreState = Chevron7.STARGATE.get().defaultBlockState().setValue(StargateBlock.FACING, facing);
			level.setBlock(core, coreState, flags);
			for(int part = 0; part < GateShape.FRAME.length; part++)
			{
				level.setBlock(GateShape.frameCell(core, facing, part), Chevron7.GATE_FRAME.get().defaultBlockState()
						.setValue(GateFrameBlock.FACING, facing).setValue(GateFrameBlock.PART, part), flags);
			}
			gates.add(core);

			// a path from the middle to the step in front of the gate
			path(level, center, core.relative(facing, 2), heightmap, flags);
		}

		// the way in, from the side away from the gates
		path(level, center, center.relative(opens.getOpposite(), 10), heightmap, flags);

		// the clearing in the middle, and the DHD facing whoever stands behind it
		for(int dx = -3; dx <= 3; dx++)
			for(int dz = -3; dz <= 3; dz++)
				if(dx * dx + dz * dz <= 10 && (dx != 0 || dz != 0))
					pathBlock(level, center.offset(dx, 0, dz), heightmap, flags);
		level.setBlock(center, Chevron7.DHD.get().defaultBlockState().setValue(DHDBlock.FACING, opens.getOpposite()), flags);
		return gates;
	}

	private static void fillDown(LevelAccessor level, BlockPos pos, int flags)
	{
		for(int i = 0; i < 6 && level.getBlockState(pos).canBeReplaced(); i++)
		{
			level.setBlock(pos, Blocks.DIRT.defaultBlockState(), flags);
			pos = pos.below();
		}
	}

	private static void path(LevelAccessor level, BlockPos from, BlockPos to, Heightmap.Types heightmap, int flags)
	{
		int steps = Math.max(Math.abs(to.getX() - from.getX()), Math.abs(to.getZ() - from.getZ()));
		for(int i = 0; i <= steps; i++)
		{
			double t = steps == 0 ? 0 : (double) i / steps;
			int x = (int) Math.round(from.getX() + (to.getX() - from.getX()) * t);
			int z = (int) Math.round(from.getZ() + (to.getZ() - from.getZ()) * t);
			pathBlock(level, new BlockPos(x, 0, z), heightmap, flags);
			pathBlock(level, new BlockPos(x + 1, 0, z), heightmap, flags);
		}
	}

	/** Turns the ground at this column into a dirt path, if it is grass or dirt. */
	private static void pathBlock(LevelAccessor level, BlockPos column, Heightmap.Types heightmap, int flags)
	{
		BlockPos ground = new BlockPos(column.getX(), level.getHeight(heightmap, column.getX(), column.getZ()) - 1, column.getZ());
		BlockState state = level.getBlockState(ground);
		if(state.is(BlockTags.DIRT) && level.getBlockState(ground.above()).isAir())
			level.setBlock(ground, Blocks.DIRT_PATH.defaultBlockState(), flags);
	}
}
