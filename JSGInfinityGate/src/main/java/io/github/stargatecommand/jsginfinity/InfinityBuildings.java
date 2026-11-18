package io.github.stargatecommand.jsginfinity;

import dev.tauri.jsg.api.blockstates.JSGProperties;
import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.LightBlock;
import net.minecraft.world.level.block.SlabBlock;
import net.minecraft.world.level.block.StairBlock;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.level.block.state.properties.SlabType;

import java.util.Map;

/**
 * Gates and the places they stand in, for the operator commands: a bare Infinity gate, the gate
 * on the stone pyramid of Carter's Addon Pack's dial sequence, and the gate room of Stargate
 * Infinity. A building's position is the ground under the middle of its gate; the gate faces
 * {@code facing}, towards whoever walks up to it.
 */
public final class InfinityBuildings {
    private InfinityBuildings() {}

    /** A placed JSG gate's centre is about this far above the bottom of its base block, and its ring this wide. */
    private static final double GATE_CENTRE = 3.5, GATE_RADIUS = 4.2;

    /** Lays out a whole Infinity gate with its base at {@code pos} and forms it; null if the base couldn't be placed. */
    public static InfinityBaseBE gate(ServerLevel level, BlockPos pos, Direction facing) {
        BlockState base = JSGInfinity.BASE_BLOCK.get().defaultBlockState()
                .setValue(JSGProperties.FACING_HORIZONTAL_PROPERTY, facing);
        level.setBlock(pos, base, 3);
        if (!(level.getBlockEntity(pos) instanceof InfinityBaseBE gate)) return null;
        gate.generateMergeHelper();
        Map<BlockPos, BlockState> blocks = gate.getMergeHelper().getBlocks();
        for (Map.Entry<BlockPos, BlockState> block : blocks.entrySet()) {
            level.setBlock(block.getKey(), block.getValue(), 3);
        }
        // what JSG does when a player places a base block: form the gate, link a DHD in range
        gate.getMergeHelper().updateMemberStateAndCheck(null);
        gate.refresh();
        return gate;
    }

    /**
     * The gate on the pyramid from the dial sequence of Carter's Addon Pack: a stepped platform of
     * dark stone with a red carpet up its front steps, on red ground, the orange DHD in front.
     */
    public static InfinityBaseBE carterPlatform(ServerLevel level, BlockPos ground, Direction facing) {
        Frame f = new Frame(level, ground, facing);
        f.fill(-11, 0, -8, 11, 13, 12, Blocks.AIR.defaultBlockState());
        // the red ground
        for (int x = -11; x <= 11; x++)
            for (int d = -8; d <= 12; d++)
                f.set(x, -1, d, mottled(x, d, 0) ? Blocks.RED_NETHER_BRICKS : Blocks.RED_TERRACOTTA);
        // the pyramid, four steps high; the middle of its front steps is the red carpet
        for (int step = 0; step < 4; step++) {
            int half = 8 - step, front = 5 - step, back = -(5 - step);
            for (int x = -half; x <= half; x++)
                for (int d = back; d <= front; d++) {
                    boolean edgeX = Math.abs(x) == half, edgeFront = d == front, edgeBack = d == back;
                    boolean carpet = Math.abs(x) <= 1;
                    BlockState block;
                    if (edgeFront && !edgeX)
                        block = stairs(carpet ? Blocks.RED_NETHER_BRICK_STAIRS : Blocks.DEEPSLATE_TILE_STAIRS, f.facing.getOpposite());
                    else if (edgeBack && !edgeX)
                        block = stairs(Blocks.DEEPSLATE_TILE_STAIRS, f.facing);
                    else if (edgeX && !edgeFront && !edgeBack)
                        block = stairs(Blocks.DEEPSLATE_TILE_STAIRS, x > 0 ? f.right.getOpposite() : f.right);
                    else if (edgeX)
                        block = Blocks.POLISHED_DEEPSLATE.defaultBlockState();
                    else
                        block = (mottled(x, d, step) ? Blocks.POLISHED_BLACKSTONE : Blocks.DEEPSLATE_TILES).defaultBlockState();
                    f.set(x, step, d, block);
                }
        }
        // the carpet across the top to the gate, and on the ground from the DHD to the steps
        for (int x = -1; x <= 1; x++) {
            f.set(x, 4, 1, Blocks.RED_CARPET.defaultBlockState());
            for (int d = 6; d <= 8; d++) f.set(x, 0, d, Blocks.RED_CARPET.defaultBlockState());
        }
        f.set(0, 0, 9, dhd(JSGInfinity.ORANGE_DHD_BLOCK.get(), facing));
        return gate(level, f.at(0, 4, 0), facing);
    }

    /**
     * The gate room of Stargate Infinity: the gate on a base at the top of a brown ramp with hot
     * pink rails, in front of a golden-brown wall with a pale halo round the gate and lime and
     * yellow light bars fanned out round that. Open at the front, the Infinity DHD by the ramp.
     */
    public static InfinityBaseBE infinityRoom(ServerLevel level, BlockPos ground, Direction facing) {
        Frame f = new Frame(level, ground, facing);
        final int half = 13, back = -3, front = 15, height = 18;
        f.fill(-half, 0, back, half, height, front, Blocks.AIR.defaultBlockState());
        // floor, ceiling and side walls: a brown floor, the show's mottled golden-brown walls
        for (int x = -half; x <= half; x++)
            for (int d = back; d <= front; d++) {
                f.set(x, -1, d, (x + d) % 2 == 0 ? Blocks.MUD_BRICKS : Blocks.PACKED_MUD);
                f.set(x, height, d, wall(x, d, height));
            }
        for (int d = back; d <= front; d++)
            for (int y = 0; y < height; y++) {
                f.set(-half, y, d, wall(-half, y, d));
                f.set(half, y, d, wall(half, y, d));
            }
        // the back wall: a pale halo round the gate, then 18 light bars fanned out round it,
        // yellow near the gate and lime further out
        double cy = 2 + GATE_CENTRE;
        for (int x = -half; x <= half; x++)
            for (int y = 0; y < height; y++) {
                double r = Math.hypot(x, y - cy);
                double a = Math.toDegrees(Math.atan2(x, y - cy)) + 360;
                double fromBar = Math.toRadians((a - 10) % 20 > 10 ? 20 - (a - 10) % 20 : (a - 10) % 20);
                boolean bar = r * Math.sin(fromBar) < 0.6 && r > GATE_RADIUS + 3 && r < GATE_RADIUS + 8;
                Block block = r < GATE_RADIUS + 1.1 ? Blocks.SMOOTH_SANDSTONE
                        : r < GATE_RADIUS + 2.2 ? Blocks.SANDSTONE
                        : bar ? (r < GATE_RADIUS + 5.2 ? Blocks.YELLOW_CONCRETE : Blocks.LIME_CONCRETE) : null;
                f.set(x, y, back, block != null ? block.defaultBlockState() : wall(x, y, back));
            }

        // the gate's base, two high, and the ramp down from it with pink rails
        f.fill(-4, 0, -2, 4, 0, 1, Blocks.PACKED_MUD.defaultBlockState());
        f.fill(-4, 1, -2, 4, 1, 1, Blocks.MUD_BRICKS.defaultBlockState());
        for (int x = -4; x <= 4; x++)
            if (Math.abs(x) >= 3) f.set(x, 1, 1, Blocks.MAGENTA_CONCRETE.defaultBlockState());
        BlockState slab = Blocks.MUD_BRICK_SLAB.defaultBlockState().setValue(SlabBlock.TYPE, SlabType.BOTTOM);
        int[] surface = {4, 3, 2, 1}; // the ramp's top, in half blocks, from the base down to the floor
        for (int i = 0; i < surface.length; i++) {
            int d = 2 + i, h = surface[i];
            for (int x = -2; x <= 2; x++) {
                for (int y = 0; y < h / 2; y++) f.set(x, y, d, Blocks.MUD_BRICKS.defaultBlockState());
                if (h % 2 == 1) f.set(x, h / 2, d, slab);
            }
            for (int x : new int[]{-3, 3}) f.fill(x, 0, d, x, (h + 1) / 2, d, Blocks.MAGENTA_CONCRETE.defaultBlockState());
        }
        for (int x : new int[]{-3, 3}) f.set(x, 0, 6, Blocks.MAGENTA_CONCRETE.defaultBlockState());

        // lights: froglights in the ceiling, invisible light blocks so the room is bright throughout
        BlockState glow = Blocks.LIGHT.defaultBlockState().setValue(LightBlock.LEVEL, 15);
        for (int x = -10; x <= 10; x += 5)
            for (int d = -1; d <= 14; d += 5) f.set(x, height, d, Blocks.OCHRE_FROGLIGHT.defaultBlockState());
        for (int x = -10; x <= 10; x += 5)
            for (int d = -1; d <= 14; d += 5)
                for (int y = 3; y <= 13; y += 5)
                    if (f.isAir(x, y, d)) f.set(x, y, d, glow);

        f.set(6, 0, 8, dhd(JSGInfinity.DHD_BLOCK.get(), facing));
        return gate(level, f.at(0, 2, 0), facing);
    }

    /** A DHD turned to face the gate, as JSG turns one placed by a player looking at it. */
    private static BlockState dhd(Block block, Direction gateFacing) {
        int rotation = Math.round(gateFacing.getOpposite().toYRot() / 22.5f) & 15;
        return block.defaultBlockState().setValue(JSGProperties.ROTATION_PROPERTY, rotation);
    }

    private static BlockState stairs(Block block, Direction up) {
        return block.defaultBlockState().setValue(StairBlock.FACING, up);
    }

    /** A stable speckle, the same each time: true for about one block in four. */
    private static boolean mottled(int a, int b, int c) {
        int h = a * 0x27d4eb2d + b * 0x165667b1 + c * 0x61c88647;
        h ^= h >>> 15;
        h *= 0x85ebca6b;
        h ^= h >>> 13;
        return (h & 15) < 4;
    }

    /** The gate room's walls: orange-brown with darker patches, like the show's painted walls. */
    private static BlockState wall(int a, int b, int c) {
        return (mottled(a, b, c) ? Blocks.TERRACOTTA : Blocks.ORANGE_TERRACOTTA).defaultBlockState();
    }

    /** Positions in a building: x along the gate (to its own right), y up, d out of the gate's front. */
    private static final class Frame {
        final ServerLevel level;
        final BlockPos origin;
        final Direction facing, right;

        Frame(ServerLevel level, BlockPos origin, Direction facing) {
            this.level = level;
            this.origin = origin;
            this.facing = facing;
            this.right = facing.getClockWise();
        }

        BlockPos at(int x, int y, int d) {
            return origin.relative(right, x).above(y).relative(facing, d);
        }

        void set(int x, int y, int d, BlockState state) {
            level.setBlock(at(x, y, d), state, 3);
        }

        boolean isAir(int x, int y, int d) {
            return level.isEmptyBlock(at(x, y, d));
        }

        void set(int x, int y, int d, Block block) {
            set(x, y, d, block.defaultBlockState());
        }

        void fill(int x0, int y0, int d0, int x1, int y1, int d1, BlockState state) {
            for (int x = Math.min(x0, x1); x <= Math.max(x0, x1); x++)
                for (int y = Math.min(y0, y1); y <= Math.max(y0, y1); y++)
                    for (int d = Math.min(d0, d1); d <= Math.max(d0, d1); d++)
                        set(x, y, d, state);
        }
    }
}
