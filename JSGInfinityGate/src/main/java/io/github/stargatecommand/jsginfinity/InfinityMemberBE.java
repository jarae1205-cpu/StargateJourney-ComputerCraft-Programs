package io.github.stargatecommand.jsginfinity;

import dev.tauri.jsg.blockentity.stargate.StargateMilkyWayMemberBE;
import net.minecraft.core.BlockPos;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;

/** A ring or chevron block of the gate; it belongs to an Infinity base block. */
public class InfinityMemberBE extends StargateMilkyWayMemberBE {
    public InfinityMemberBE(BlockPos pos, BlockState state) {
        super(JSGInfinity.MEMBER_BE.get(), pos, state);
    }

    @Override
    public Block getBaseBlock() {
        return JSGInfinity.BASE_BLOCK.get();
    }
}
