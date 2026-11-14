package io.github.stargatecommand.chevron7;

import java.util.Locale;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.SlabBlock;
import net.minecraft.world.level.block.StairBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.Half;
import net.minecraft.world.level.block.state.properties.SlabType;
import net.minecraft.world.level.block.state.properties.StairsShape;

/**
 * Gates with something built around them: a raised platform with stairs up to the gate, and a
 * gate room in the style of the animated series. Positions are given in the gate's own frame:
 * {@code x} to the right as you face the gate, {@code d} towards the front (where you stand to
 * walk in), {@code y} up from the ground.
 */
public final class GateBuildings
{
	private GateBuildings() {}

	private static final int FLAGS = Block.UPDATE_CLIENTS;

	/** The stone a platform is made of. */
	public enum Style
	{
		STONE(Blocks.STONE_BRICKS, Blocks.POLISHED_ANDESITE, Blocks.STONE_BRICK_STAIRS, Blocks.STONE_BRICK_WALL),
		DEEPSLATE(Blocks.DEEPSLATE_BRICKS, Blocks.POLISHED_DEEPSLATE, Blocks.DEEPSLATE_BRICK_STAIRS, Blocks.DEEPSLATE_BRICK_WALL),
		SANDSTONE(Blocks.CUT_SANDSTONE, Blocks.SMOOTH_SANDSTONE, Blocks.SMOOTH_SANDSTONE_STAIRS, Blocks.SANDSTONE_WALL),
		BLACKSTONE(Blocks.POLISHED_BLACKSTONE_BRICKS, Blocks.POLISHED_BLACKSTONE, Blocks.POLISHED_BLACKSTONE_BRICK_STAIRS,
				Blocks.POLISHED_BLACKSTONE_BRICK_WALL),
		/** The Carter Addon Pack look: a sloped stone pedestal with a red carpet up to the gate. */
		CAP(Blocks.POLISHED_DEEPSLATE, Blocks.DEEPSLATE_TILES, Blocks.POLISHED_DEEPSLATE_STAIRS, Blocks.POLISHED_DEEPSLATE_WALL);

		final Block body, top, stairs, wall;

		Style(Block body, Block top, Block stairs, Block wall)
		{
			this.body = body;
			this.top = top;
			this.stairs = stairs;
			this.wall = wall;
		}

		@Nullable
		public static Style byName(String name)
		{
			for(Style style : values())
				if(style.name().toLowerCase(Locale.ROOT).equals(name.toLowerCase(Locale.ROOT)))
					return style;
			return null;
		}
	}

	private record Frame(LevelAccessor level, BlockPos origin, Direction facing, Direction right)
	{
		BlockPos at(int x, int y, int d)
		{
			return origin.relative(right, x).relative(facing, d).above(y);
		}

		void set(int x, int y, int d, BlockState state)
		{
			level.setBlock(at(x, y, d), state, FLAGS);
		}

		void set(int x, int y, int d, Block block)
		{
			set(x, y, d, block.defaultBlockState());
		}

		/** Stairs that you walk up towards the gate. */
		void stairs(int x, int y, int d, Block stairs)
		{
			set(x, y, d, stairs.defaultBlockState().setValue(StairBlock.FACING, facing.getOpposite())
					.setValue(StairBlock.HALF, Half.BOTTOM).setValue(StairBlock.SHAPE, StairsShape.STRAIGHT));
		}

		void fill(int x0, int y0, int d0, int x1, int y1, int d1, Block block)
		{
			for(int x = Math.min(x0, x1); x <= Math.max(x0, x1); x++)
				for(int y = Math.min(y0, y1); y <= Math.max(y0, y1); y++)
					for(int d = Math.min(d0, d1); d <= Math.max(d0, d1); d++)
						set(x, y, d, block);
		}

		/** Something to stand on under a column: fills down to the ground. */
		void foundation(int x, int d, Block block)
		{
			BlockPos pos = at(x, -1, d);
			for(int i = 0; i < 12 && level.getBlockState(pos).canBeReplaced(); i++, pos = pos.below())
				level.setBlock(pos, block.defaultBlockState(), FLAGS);
		}
	}

	/**
	 * Places a gate whose stargate block (the bottom middle of the ring) is at {@code core}.
	 * @return the gate, to give it an address or an iris
	 */
	@Nullable
	public static StargateBlockEntity placeGate(LevelAccessor level, BlockPos core, Direction facing, GateLook look)
	{
		level.setBlock(core, Chevron7.STARGATE.get().defaultBlockState().setValue(StargateBlock.FACING, facing), FLAGS);
		for(int part = 0; part < GateShape.FRAME.length; part++)
		{
			level.setBlock(GateShape.frameCell(core, facing, part), Chevron7.GATE_FRAME.get().defaultBlockState()
					.setValue(GateFrameBlock.FACING, facing).setValue(GateFrameBlock.PART, part), FLAGS);
		}
		if(level.getBlockEntity(core) instanceof StargateBlockEntity gate)
		{
			gate.setLook(look);
			return gate;
		}
		return null;
	}

	/**
	 * A gate on a raised platform: an 11 by 6 dais two blocks high with stairs up the front,
	 * the gate's own step on top, a lantern on a post at each front corner and a DHD below.
	 * @param ground the first block above the ground, under the middle of the gate
	 * @return the gate
	 */
	@Nullable
	public static StargateBlockEntity platform(LevelAccessor level, BlockPos ground, Direction facing, GateLook look, Style style)
	{
		if(style == Style.CAP)
			return capPlatform(level, ground, facing, look);
		Frame f = new Frame(level, ground, facing, GateShape.right(facing));
		// room for it all: the dais, the gate and the plaza in front
		f.fill(-6, 0, -4, 6, 11, 8, Blocks.AIR);
		for(int x = -6; x <= 6; x++)
			for(int d = -4; d <= 8; d++)
				f.foundation(x, d, Blocks.STONE);

		// the plaza in front and the ground around the dais
		for(int x = -6; x <= 6; x++)
			for(int d = -4; d <= 8; d++)
				f.set(x, -1, d, Math.abs(x) == 6 || d == -4 || d == 8 ? style.body : style.top);

		// the dais: body below, a smooth top with an edge of the body stone
		f.fill(-5, 0, -3, 5, 0, 2, style.body);
		for(int x = -5; x <= 5; x++)
			for(int d = -3; d <= 2; d++)
				f.set(x, 1, d, Math.abs(x) == 5 || d == -3 || d == 2 && Math.abs(x) > 2 ? style.body : style.top);

		// two steps up the front, five wide
		for(int x = -2; x <= 2; x++)
		{
			f.stairs(x, 0, 4, style.stairs);
			f.set(x, 0, 3, style.body);
			f.stairs(x, 1, 3, style.stairs);
		}

		// lantern posts at the front corners of the dais
		for(int x : new int[] {-5, 5})
		{
			f.set(x, 2, 2, style.wall);
			f.set(x, 3, 2, style.wall);
			f.set(x, 4, 2, Blocks.LANTERN);
		}

		BlockPos core = f.at(0, 2, 0);
		StargateBlockEntity gate = placeGate(level, core, facing, look);
		GateField.placeStep(level, core, facing, style.stairs, FLAGS);
		level.setBlock(f.at(4, 0, 6), Chevron7.DHD.get().defaultBlockState().setValue(DHDBlock.FACING, facing), FLAGS);
		return gate;
	}

	/** Pedestal sizes: the half width of the top, for 7-wide gates or for JSG's 11-wide ones. */
	public static final int PEDESTAL_SMALL = 5, PEDESTAL_LARGE = 7;
	/** How high the pedestal is: a gate on it stands this many blocks above the ground. */
	public static final int PEDESTAL_HEIGHT = 3;

	/**
	 * A sloped stone pedestal in the style of the Carter Addon Pack, with no gate: three layers that
	 * step in towards the top, stairs down every side, a red carpet up the middle of the front and a
	 * red floor around it. A gate of any mod can stand on top.
	 * @param ground the first block above the ground, under the middle of the gate
	 * @param half the half width of the top (PEDESTAL_SMALL or PEDESTAL_LARGE)
	 * @return where the gate's base (the bottom middle of the ring) goes
	 */
	public static BlockPos pedestal(LevelAccessor level, BlockPos ground, Direction facing, int half)
	{
		Frame f = new Frame(level, ground, facing, GateShape.right(facing));
		final int top = PEDESTAL_HEIGHT - 1, depth = 2;
		int wide = half + PEDESTAL_HEIGHT + 3, back = -depth - PEDESTAL_HEIGHT - 3, front = depth + PEDESTAL_HEIGHT + 6;
		// room for it all, and something to stand on
		f.fill(-wide, 0, back, wide, PEDESTAL_HEIGHT + 12, front, Blocks.AIR);
		for(int x = -wide; x <= wide; x++)
			for(int d = back; d <= front; d++)
			{
				f.foundation(x, d, Blocks.STONE);
				boolean edge = Math.abs(x) == wide || d == back || d == front;
				f.set(x, -1, d, edge ? Blocks.POLISHED_BLACKSTONE_BRICKS : Blocks.RED_TERRACOTTA);
			}
		// three layers, each one block wider all round than the one above it
		for(int y = 0; y <= top; y++)
		{
			int grow = top - y, xh = half + grow, d0 = -depth - grow, d1 = depth + grow;
			for(int x = -xh; x <= xh; x++)
				for(int d = d0; d <= d1; d++)
				{
					boolean rim = Math.abs(x) == xh || d == d0 || d == d1;
					if(!rim || y == top)
						f.set(x, y, d, y == top && !rim ? Style.CAP.top : Style.CAP.body);
					else
						f.set(x, y, d, slope(f, x, d, xh, d0, d1));
				}
		}
		// the red carpet: up the front in three steps, then along the top to the gate
		for(int x = -1; x <= 1; x++)
		{
			for(int step = 0; step < PEDESTAL_HEIGHT; step++)
			{
				int d = depth + 1 + step, y = top - step;
				for(int below = 0; below < y; below++)
					f.set(x, below, d, Blocks.RED_NETHER_BRICKS);
				f.stairs(x, y, d, Blocks.RED_NETHER_BRICK_STAIRS);
			}
			for(int d = 1; d <= depth; d++)
				f.set(x, top, d, Blocks.RED_NETHER_BRICKS);
		}
		// turn the stairs at the corners, the way they would turn if a player placed them
		for(int y = 0; y < top; y++)
		{
			int grow = top - y, xh = half + grow;
			for(int x = -xh; x <= xh; x++)
				for(int d = -depth - grow; d <= depth + grow; d++)
				{
					BlockPos pos = f.at(x, y, d);
					BlockState state = level.getBlockState(pos);
					if(state.getBlock() instanceof StairBlock)
						level.setBlock(pos, Block.updateFromNeighbourShapes(state, level, pos), FLAGS);
				}
		}
		return f.at(0, PEDESTAL_HEIGHT, 0);
	}

	/** Stairs going down the side of a pedestal layer, facing out; the corners turn. */
	private static BlockState slope(Frame f, int x, int d, int xh, int d0, int d1)
	{
		Direction out;
		boolean end = d == d0 || d == d1;
		Direction along = d == d1 ? f.facing() : f.facing().getOpposite();
		Direction across = x > 0 ? f.right() : f.right().getOpposite();
		out = end ? along : across;
		return Style.CAP.stairs.defaultBlockState().setValue(StairBlock.FACING, out.getOpposite())
				.setValue(StairBlock.HALF, Half.BOTTOM);
	}

	/**
	 * A gate on a Carter Addon Pack pedestal: the gate on top with its step, the red carpet up to it
	 * and the DHD at the foot of the carpet.
	 * @param ground the first block above the ground, under the middle of the gate
	 * @return the gate
	 */
	@Nullable
	public static StargateBlockEntity capPlatform(LevelAccessor level, BlockPos ground, Direction facing, GateLook look)
	{
		BlockPos core = pedestal(level, ground, facing, PEDESTAL_SMALL);
		StargateBlockEntity gate = placeGate(level, core, facing, look);
		GateField.placeStep(level, core, facing, Blocks.RED_NETHER_BRICK_STAIRS, FLAGS);
		Frame f = new Frame(level, ground, facing, GateShape.right(facing));
		level.setBlock(f.at(0, 0, 2 + PEDESTAL_HEIGHT + 2), Chevron7.DHD.get().defaultBlockState().setValue(DHDBlock.FACING, facing)
				.setValue(DHDBlock.CAP, true), FLAGS);
		return gate;
	}

	/**
	 * An Ori supergate: SupergateBlock.SCALE times the size of a gate, its ring drawn as separate
	 * segments. Clears the space for the ring and stands its base on the ground.
	 * @param ground the first block above the ground, under the middle of the ring
	 * @return the gate
	 */
	@Nullable
	public static StargateBlockEntity supergate(LevelAccessor level, BlockPos ground, Direction facing)
	{
		Frame f = new Frame(level, ground, facing, GateShape.right(facing));
		int reach = (int) Math.ceil(3.5 * SupergateBlock.SCALE), height = 7 * SupergateBlock.SCALE + 1;
		f.fill(-reach, 0, -1, reach, height, 1, Blocks.AIR);
		f.foundation(0, 0, Blocks.STONE);
		level.setBlock(ground, Chevron7.SUPERGATE.get().defaultBlockState().setValue(StargateBlock.FACING, facing), FLAGS);
		// the bottom of the horizon is this far up, so a landing under it and stairs up the front
		int lift = (int) Math.ceil(GateShape.CENTER_HEIGHT - 3.42 + (3.42 - GateShape.HORIZON_RADIUS) * SupergateBlock.SCALE);
		for(int x = -2; x <= 2; x++)
		{
			for(int y = 0; y < lift; y++)
				for(int d = 0; d <= 1; d++)
					if(x != 0 || y != 0 || d != 0)
						f.set(x, y, d, Blocks.POLISHED_BLACKSTONE_BRICKS);
			for(int step = 1; step <= lift; step++)
			{
				int d = 1 + step, y = lift - step;
				for(int below = 0; below < y; below++)
					f.set(x, below, d, Blocks.POLISHED_BLACKSTONE_BRICKS);
				f.stairs(x, y, d, Blocks.POLISHED_BLACKSTONE_BRICK_STAIRS);
			}
		}
		if(level.getBlockEntity(ground) instanceof StargateBlockEntity gate)
		{
			gate.setLook(GateLook.ORI);
			return gate;
		}
		return null;
	}

	/**
	 * One gate in every look side by side on a paved strip, each on its step, with a DHD in front
	 * of the middle one and an Ori supergate behind them.
	 * @param ground the first block above the ground, under the middle gate
	 */
	public static void gateRow(LevelAccessor level, BlockPos ground, Direction facing)
	{
		Frame f = new Frame(level, ground, facing, GateShape.right(facing));
		GateLook[] looks = GateLook.values();
		int spacing = 9, half = looks.length / 2 * spacing + 5;
		f.fill(-half, 0, -2, half, 8, 4, Blocks.AIR);
		for(int x = -half; x <= half; x++)
			for(int d = -2; d <= 4; d++)
			{
				f.foundation(x, d, Blocks.STONE);
				f.set(x, -1, d, d == -2 || d == 4 || Math.abs(x) == half ? Blocks.STONE_BRICKS : Blocks.POLISHED_ANDESITE);
			}
		for(int i = 0; i < looks.length; i++)
		{
			BlockPos core = f.at((i - looks.length / 2) * spacing, 0, 0);
			placeGate(level, core, facing, looks[i]);
			GateField.placeStep(level, core, facing, Blocks.STONE_BRICK_STAIRS, FLAGS);
		}
		level.setBlock(f.at(0, 0, 4), Chevron7.DHD.get().defaultBlockState().setValue(DHDBlock.FACING, facing), FLAGS);
		supergate(level, f.at(0, 0, -18), facing);
	}

	/** The gate room's golden-brown wall, with darker and lighter patches like the painted walls of the show. */
	private static Block mottled(int a, int b, int c)
	{
		int h = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791);
		h = (h ^ (h >>> 13)) & 15;
		return h < 4 ? Blocks.ORANGE_TERRACOTTA : Blocks.TERRACOTTA;
	}

	/**
	 * A gate room after the animated series: the gate (Infinity look) on a base at the top of a
	 * brown ramp with hot pink rails, in front of a wall with a pale halo around the gate and lime
	 * light bars fanned out around it. The room is open at the front.
	 * @param ground the floor, under the middle of the gate
	 * @return the gate
	 */
	@Nullable
	public static StargateBlockEntity gateRoom(LevelAccessor level, BlockPos ground, Direction facing)
	{
		Frame f = new Frame(level, ground, facing, GateShape.right(facing));
		final int half = 12, back = -3, front = 14, height = 15;

		// clear it, then floor, walls and ceiling: the show's mottled golden-brown walls and a brown floor
		f.fill(-half, 0, back, half, height, front, Blocks.AIR);
		for(int x = -half; x <= half; x++)
			for(int d = back; d <= front; d++)
			{
				f.foundation(x, d, Blocks.STONE);
				f.set(x, -1, d, (x + d) % 2 == 0 ? Blocks.MUD_BRICKS : Blocks.PACKED_MUD);
				f.set(x, height, d, mottled(x, d, height));
			}
		for(int d = back; d <= front; d++)
			for(int y = 0; y < height; y++)
			{
				f.set(-half, y, d, mottled(-half, y, d));
				f.set(half, y, d, mottled(half, y, d));
			}
		// lights in the ceiling, and invisible light blocks so the whole room is bright
		for(int x = -8; x <= 8; x += 8)
			for(int d = 2; d <= 12; d += 5)
				f.set(x, height, d, Blocks.OCHRE_FROGLIGHT);
		BlockState glow = Blocks.LIGHT.defaultBlockState().setValue(net.minecraft.world.level.block.LightBlock.LEVEL, 15);
		for(int x = -9; x <= 9; x += 6)
			for(int d = 3; d <= 12; d += 4)
				for(int y = 5; y <= 11; y += 6)
					f.set(x, y, d, glow);
		for(int x = -6; x <= 6; x += 6)
			f.set(x, 10, -2, glow);

		// the back wall: a pale halo around the gate, lime light bars beyond it
		double cy = 2 + GateShape.CENTER_HEIGHT - 0.5;
		for(int x = -half; x <= half; x++)
			for(int y = 0; y < height; y++)
			{
				double r = Math.sqrt(x * x + (y - cy) * (y - cy));
				Block block = r < 4.6 ? Blocks.SMOOTH_SANDSTONE : r < 5.8 ? Blocks.SANDSTONE : mottled(x, y, back);
				f.set(x, y, back, block);
			}
		for(int bar = 0; bar < 18; bar++)
		{
			double a = Math.toRadians(bar * 20 + 10);
			for(double r = 6.6; r <= 10.4; r += 0.25)
			{
				int x = (int) Math.round(r * Math.sin(a));
				int y = (int) Math.round(cy + r * Math.cos(a));
				// yellow near the gate, lime further out, like the show's light bars
				if(Math.abs(x) < half && y >= 0 && y < height)
					f.set(x, y, back, r < 8.4 ? Blocks.YELLOW_CONCRETE : Blocks.LIME_CONCRETE);
			}
		}

		// the gate's base and the ramp up to it, five wide with red rails
		// (brown, with hot pink rails, as in the show)
		f.fill(-4, 0, -2, 4, 1, 1, Blocks.PACKED_MUD);
		f.fill(-4, 1, -2, 4, 1, 1, Blocks.MUD_BRICKS);
		BlockState slab = Blocks.MUD_BRICK_SLAB.defaultBlockState().setValue(SlabBlock.TYPE, SlabType.BOTTOM);
		// height of the ramp's surface in half blocks, from the base down to the floor
		int[] surface = {4, 3, 2, 1};
		for(int i = 0; i < surface.length; i++)
		{
			int d = 2 + i, h = surface[i];
			for(int x = -2; x <= 2; x++)
			{
				for(int y = 0; y < h / 2; y++)
					f.set(x, y, d, Blocks.MUD_BRICKS);
				if(h % 2 == 1)
					f.set(x, h / 2, d, slab);
			}
			int rail = (h + 1) / 2;
			for(int x : new int[] {-3, 3})
			{
				f.fill(x, 0, d, x, rail, d, Blocks.MAGENTA_CONCRETE);
			}
		}
		for(int x : new int[] {-3, 3})
			f.set(x, 0, 6, Blocks.MAGENTA_CONCRETE);
		// the edges of the base
		for(int x = -4; x <= 4; x++)
			if(Math.abs(x) >= 3)
				f.set(x, 2, 1, Blocks.MAGENTA_CONCRETE);

		BlockPos core = f.at(0, 2, 0);
		StargateBlockEntity gate = placeGate(level, core, facing, GateLook.INFINITY);
		GateField.placeStep(level, core, facing, Blocks.MUD_BRICK_STAIRS, FLAGS);
		level.setBlock(f.at(6, 0, 8), Chevron7.DHD.get().defaultBlockState().setValue(DHDBlock.FACING, facing), FLAGS);
		return gate;
	}
}
