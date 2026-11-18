package io.github.stargatecommand.chevron7;

import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.tags.BlockTags;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.StairBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.Half;
import net.minecraft.world.level.block.state.properties.StairsShape;
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

	/** Trees, giant mushrooms and plants: what stands on the ground, not the ground itself. */
	static boolean growth(BlockState state)
	{
		if(state.isAir())
			return false;
		return state.is(BlockTags.LOGS) || state.is(BlockTags.LEAVES) || state.is(Blocks.MUSHROOM_STEM)
				|| state.is(Blocks.BROWN_MUSHROOM_BLOCK) || state.is(Blocks.RED_MUSHROOM_BLOCK) || state.is(Blocks.BAMBOO)
				|| state.is(Blocks.BEE_NEST) || state.is(Blocks.VINE)
				|| (!state.blocksMotion() && state.getFluidState().isEmpty());
	}

	/**
	 * The height of the first block above real ground in a column: below any trees, giant
	 * mushrooms and plants. (The heightmaps count tree trunks, so a gate could land on a tree.)
	 */
	public static int groundY(LevelAccessor level, int x, int z, Heightmap.Types heightmap)
	{
		BlockPos.MutableBlockPos pos = new BlockPos.MutableBlockPos(x, level.getHeight(heightmap, x, z) - 1, z);
		int bottom = level.getMinBuildHeight();
		while(pos.getY() > bottom)
		{
			BlockState state = level.getBlockState(pos);
			if(!state.isAir() && !growth(state))
				break;
			pos.move(Direction.DOWN);
		}
		return pos.getY() + 1;
	}

	/** The lowest and highest ground under the field, to see if it is flat enough. */
	public static int[] groundRange(LevelAccessor level, BlockPos center, Direction opens, int count, Heightmap.Types heightmap)
	{
		int min = groundY(level, center.getX(), center.getZ(), heightmap);
		int max = min;
		for(Site site : plan(center, opens, count))
		{
			int y = groundY(level, site.core().getX(), site.core().getZ(), heightmap);
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
		int centerY = groundY(level, centerColumn.getX(), centerColumn.getZ(), heightmap);
		BlockPos center = new BlockPos(centerColumn.getX(), centerY, centerColumn.getZ());

		List<BlockPos> gates = new ArrayList<>();
		for(Site site : plan(center, opens, count))
		{
			int y = groundY(level, site.core().getX(), site.core().getZ(), heightmap);
			BlockPos core = new BlockPos(site.core().getX(), y, site.core().getZ());
			Direction facing = site.facing();
			Direction right = GateShape.right(facing);

			// no tree trunk through the ring, no canopy over it
			for(int x = -5; x <= 5; x++)
				for(int depth = -3; depth <= 3; depth++)
					clearGrowth(level, core.relative(right, x).relative(facing, depth).below(2), 15, flags);

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
			placeStep(level, core, facing, Blocks.STONE_BRICK_STAIRS, flags);
			// the ground just in front of the step, level with it, so the path meets it
			for(int x = -1; x <= 1; x++)
				for(int depth = 2; depth <= 3; depth++)
					level(level, core.relative(right, x).relative(facing, depth), y, 3, heightmap, flags);

			// a path from the middle to the step in front of the gate
			path(level, center, core.relative(facing, 2), heightmap, flags);
		}

		// the way in, from the side away from the gates
		path(level, center, center.relative(opens.getOpposite(), 10), heightmap, flags);

		// the clearing in the middle, level with the DHD, which faces whoever stands behind it
		for(int dx = -4; dx <= 4; dx++)
			for(int dz = -4; dz <= 4; dz++)
				if(dx * dx + dz * dz <= 17)
					clearGrowth(level, center.offset(dx, -3, dz), 12, flags);
		for(int dx = -3; dx <= 3; dx++)
			for(int dz = -3; dz <= 3; dz++)
				if(dx * dx + dz * dz <= 10)
				{
					level(level, center.offset(dx, 0, dz), centerY, 3, heightmap, flags);
					if(dx != 0 || dz != 0)
						pathBlock(level, center.offset(dx, 0, dz), heightmap, flags);
				}
		level.setBlock(center, Chevron7.DHD.get().defaultBlockState().setValue(DHDBlock.FACING, opens.getOpposite()), flags);
		return gates;
	}

	/**
	 * The bottom of the ring is a solid block. A row of three stairs in front of it, rising
	 * towards the gate, lets people walk into the event horizon instead of jumping.
	 */
	public static void placeStep(LevelAccessor level, BlockPos core, Direction facing, Block stairs, int flags)
	{
		BlockState step = stairs.defaultBlockState()
				.setValue(StairBlock.FACING, facing.getOpposite())
				.setValue(StairBlock.HALF, Half.BOTTOM)
				.setValue(StairBlock.SHAPE, StairsShape.STRAIGHT);
		Direction right = GateShape.right(facing);
		for(int x = -1; x <= 1; x++)
			level.setBlock(core.relative(right, x).relative(facing), step, flags);
	}

	/** Takes out trees, giant mushrooms and plants from {@code height} blocks of a column, from {@code from} up. */
	private static void clearGrowth(LevelAccessor level, BlockPos from, int height, int flags)
	{
		BlockPos.MutableBlockPos pos = from.mutable();
		for(int i = 0; i < height; i++, pos.move(Direction.UP))
		{
			BlockState state = level.getBlockState(pos);
			if(!growth(state))
				continue;
			level.setBlock(pos, Blocks.AIR.defaultBlockState(), flags);
			if(wood(state))
				fell(level, pos.immutable(), flags);
		}
	}

	/** Trunks, branches and giant mushrooms: these don't decay like leaves do. */
	private static boolean wood(BlockState state)
	{
		return state.is(BlockTags.LOGS) || state.is(Blocks.MUSHROOM_STEM) || state.is(Blocks.BROWN_MUSHROOM_BLOCK)
				|| state.is(Blocks.RED_MUSHROOM_BLOCK);
	}

	/**
	 * Takes away the rest of a tree or giant mushroom that was cut, so no trunk or cap is left
	 * hanging in the air; its leaves decay by themselves. Only in a live world: during world
	 * generation a tree could reach outside the chunks being generated.
	 */
	private static void fell(LevelAccessor level, BlockPos start, int flags)
	{
		if(!(level instanceof net.minecraft.server.level.ServerLevel))
			return;
		ArrayDeque<BlockPos> queue = new ArrayDeque<>();
		Set<BlockPos> seen = new HashSet<>();
		queue.add(start);
		seen.add(start);
		int removed = 0;
		while(!queue.isEmpty() && removed < 600)
		{
			BlockPos pos = queue.poll();
			for(BlockPos next : BlockPos.betweenClosed(pos.offset(-1, -1, -1), pos.offset(1, 1, 1)))
			{
				if(next.distManhattan(start) > 24 || !seen.add(next.immutable()) || !wood(level.getBlockState(next)))
					continue;
				level.setBlock(next, Blocks.AIR.defaultBlockState(), flags);
				removed++;
				queue.add(next.immutable());
			}
		}
	}

	/**
	 * Makes the ground of a column end at {@code y - 1}: cuts down a bump or fills a dip, by at
	 * most {@code limit} blocks (further than that, the land is left as it is).
	 */
	private static void level(LevelAccessor level, BlockPos column, int y, int limit, Heightmap.Types heightmap, int flags)
	{
		int ground = groundY(level, column.getX(), column.getZ(), heightmap);
		if(ground == y || Math.abs(ground - y) > limit)
			return;
		for(int h = Math.min(ground, y) - 1; h < Math.max(ground, y) + 4; h++)
		{
			BlockPos pos = new BlockPos(column.getX(), h, column.getZ());
			if(h < y)
			{
				if(level.getBlockState(pos).canBeReplaced() || growth(level.getBlockState(pos)))
					level.setBlock(pos, Blocks.DIRT.defaultBlockState(), flags);
			}
			else if(!level.getBlockState(pos).isAir())
				level.setBlock(pos, Blocks.AIR.defaultBlockState(), flags);
		}
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
			for(int dx = 0; dx <= 1; dx++)
			{
				// headroom: no trunks, low branches or bushes on the path
				int ground = groundY(level, x + dx, z, heightmap);
				clearGrowth(level, new BlockPos(x + dx, ground, z), 5, flags);
				pathBlock(level, new BlockPos(x + dx, 0, z), heightmap, flags);
			}
		}
	}

	/** Turns the ground at this column into a dirt path, if it is grass or dirt. */
	private static void pathBlock(LevelAccessor level, BlockPos column, Heightmap.Types heightmap, int flags)
	{
		BlockPos ground = new BlockPos(column.getX(), groundY(level, column.getX(), column.getZ(), heightmap) - 1, column.getZ());
		BlockState state = level.getBlockState(ground);
		if(state.is(BlockTags.DIRT) && level.getBlockState(ground.above()).isAir())
			level.setBlock(ground, Blocks.DIRT_PATH.defaultBlockState(), flags);
	}
}
