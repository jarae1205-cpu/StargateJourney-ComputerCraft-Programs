package io.github.stargatecommand.jsginfinity;

import dev.tauri.jsg.api.blockstates.JSGProperties;
import dev.tauri.jsg.blockentity.stargate.StargateMilkyWayBaseBE;
import net.minecraft.core.BlockPos;
import net.minecraft.server.level.ServerPlayer;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.block.state.BlockState;

/**
 * The gate itself: JSG's Milky Way gate, unchanged, except that it forms from the Infinity blocks
 * and gives back an Infinity base block when broken. Its type stays JSG's Milky Way type, so
 * addresses, the DHD, dialing and computers treat it as a Milky Way gate.
 */
public class InfinityBaseBE extends StargateMilkyWayBaseBE {
    public InfinityBaseBE(BlockPos pos, BlockState state) {
        super(JSGInfinity.BASE_BE.get(), pos, state);
    }

    /** As JSG's own, with the Infinity ring and chevron blocks to match against. */
    @Override
    public void generateMergeHelper() {
        mergeHelper = new InfinityMergeHelper(this);
        mergeHelper.horizontalFacing = getBlockState().getValue(JSGProperties.FACING_HORIZONTAL_PROPERTY);
        mergeHelper.verticalFacing = JSGProperties.getDirectionByVerticalFacing(getBlockState().getValue(JSGProperties.FACING_VERTICAL_PROPERTY));
        mergeHelper.stargateSize = getStargateSize();
        mergeHelper.basePos = getBlockPos();
    }

    /** JSG's drop (with the gate's stored energy and upgrades), as an Infinity base block. */
    @Override
    public ItemStack getDropBaseBlock(ServerPlayer player) {
        ItemStack jsgDrop = super.getDropBaseBlock(player);
        ItemStack drop = new ItemStack(JSGInfinity.BASE_ITEM.get(), Math.max(1, jsgDrop.getCount()));
        if (jsgDrop.getTag() != null) drop.setTag(jsgDrop.getTag().copy());
        return drop;
    }
}
