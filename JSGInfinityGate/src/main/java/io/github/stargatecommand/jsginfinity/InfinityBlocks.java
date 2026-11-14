package io.github.stargatecommand.jsginfinity;

import dev.tauri.jsg.api.block.stargate.IStargateChevronBlock;
import dev.tauri.jsg.api.block.stargate.IStargateRingBlock;
import dev.tauri.jsg.block.stargate.StargateMilkyWayBaseBlock;
import dev.tauri.jsg.block.stargate.StargateMilkyWayMemberBlock;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.block.state.BlockState;

/** The three blocks of the gate. They behave as JSG's Milky Way blocks; only their block entities differ. */
public final class InfinityBlocks {
    private InfinityBlocks() {}

    /** Placed first; when the ring around it is complete, the gate forms. */
    public static class Base extends StargateMilkyWayBaseBlock {
        @Override
        public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
            return new InfinityBaseBE(pos, state);
        }
    }

    public static class Ring extends StargateMilkyWayMemberBlock implements IStargateRingBlock {
        @Override
        public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
            return new InfinityMemberBE(pos, state);
        }
    }

    public static class Chevron extends StargateMilkyWayMemberBlock implements IStargateChevronBlock {
        @Override
        public BlockEntity newBlockEntity(BlockPos pos, BlockState state) {
            return new InfinityMemberBE(pos, state);
        }
    }
}
