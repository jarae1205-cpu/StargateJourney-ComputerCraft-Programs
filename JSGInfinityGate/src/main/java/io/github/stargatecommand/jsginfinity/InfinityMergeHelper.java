package io.github.stargatecommand.jsginfinity;

import dev.tauri.jsg.blockentity.stargate.StargateAbstractBaseBE;
import dev.tauri.jsg.multistructure.mergehelper.StargateMilkyWayMergeHelper;
import net.minecraft.world.level.block.Block;

/** JSG's Milky Way pattern of ring and chevron blocks, filled with the Infinity blocks. */
public class InfinityMergeHelper extends StargateMilkyWayMergeHelper {
    public InfinityMergeHelper(StargateAbstractBaseBE<?, ?> base) {
        super(base);
    }

    @Override
    public Block getRingBlock() {
        return JSGInfinity.RING_BLOCK.get();
    }

    @Override
    public Block getChevronBlock() {
        return JSGInfinity.CHEVRON_BLOCK.get();
    }
}
