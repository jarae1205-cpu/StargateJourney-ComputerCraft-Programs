package io.github.stargatecommand.jsginfinity;

import dev.tauri.jsg.registry.BlockEntityRegistry;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraftforge.fml.util.ObfuscationReflectionHelper;

import java.lang.reflect.Field;
import java.util.HashSet;
import java.util.Set;

/**
 * The add-on's DHDs keep JSG's own Milky Way DHD block entity, whose type lists the blocks it
 * may stand in. Minecraft won't tick (or save as live) a block entity on a block missing from
 * that list, so the add-on's DHD blocks are added to it once the registries are complete.
 */
final class InfinityDhdType {
    /** BlockEntityType.validBlocks, by its runtime name. */
    private static final String VALID_BLOCKS = "f_58915_";

    private InfinityDhdType() {}

    @SuppressWarnings("unchecked")
    static void allowInfinityDhd() {
        BlockEntityType<?> type = BlockEntityRegistry.DHD_MILKYWAY.get();
        Set<Block> ours = Set.of(JSGInfinity.DHD_BLOCK.get(), JSGInfinity.ORANGE_DHD_BLOCK.get());
        if (ours.stream().allMatch(b -> type.isValid(b.defaultBlockState()))) return;
        try {
            Field field = ObfuscationReflectionHelper.findField(BlockEntityType.class, VALID_BLOCKS);
            Set<Block> blocks = new HashSet<>((Set<Block>) field.get(type));
            blocks.addAll(ours);
            field.set(type, blocks);
        } catch (ReflectiveOperationException | RuntimeException e) {
            throw new IllegalStateException("Couldn't let JSG's DHD block entity stand in the add-on's DHDs", e);
        }
    }
}
