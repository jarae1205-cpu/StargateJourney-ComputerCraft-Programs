package io.github.stargatecommand.jsginfinity;

import dev.tauri.jsg.api.raycaster.Raycaster;
import dev.tauri.jsg.raycaster.instances.RaycasterMilkyWayDHD;
import dev.tauri.jsg.registry.BlockEntityRegistry;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraftforge.fml.util.ObfuscationReflectionHelper;

import java.lang.reflect.Field;
import java.util.HashSet;
import java.util.Set;

/**
 * The add-on's DHDs are JSG's Milky Way DHD on blocks of their own, and two lists in JSG and
 * Minecraft go by the exact block:
 * <ul>
 * <li>The block entity type lists the blocks its block entity may stand in. Minecraft won't tick
 * (or save as live) a block entity on a block missing from that list.</li>
 * <li>JSG finds which key a player pressed with a raycaster registered for the DHD's exact block
 * class. Without one, pressing a key on the add-on's DHDs does nothing.</li>
 * </ul>
 * The add-on's DHD blocks join both once the registries are complete.
 */
final class InfinityDhdType {
    /** BlockEntityType.validBlocks, by its runtime name. */
    private static final String VALID_BLOCKS = "f_58915_";

    private InfinityDhdType() {}

    static void allowInfinityDhd() {
        Raycaster.register(InfinityBlocks.Dhd.class, RaycasterMilkyWayDHD.INSTANCE); // the orange DHD: JSG's keys
        Raycaster.register(InfinityBlocks.ScreenDhd.class, InfinityScreen.Raycaster.INSTANCE); // the keys on the screen
        allowBlockEntity();
    }

    @SuppressWarnings("unchecked")
    private static void allowBlockEntity() {
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
