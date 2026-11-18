package io.github.stargatecommand.jsginfinity.client;

import dev.tauri.jsg.blockentity.dialhomedevice.DHDAbstractBE;
import dev.tauri.jsg.blockentity.stargate.StargateAbstractBaseBE;
import dev.tauri.jsg.registry.BlockEntityRegistry;
import io.github.stargatecommand.jsginfinity.JSGInfinity;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.eventbus.api.EventPriority;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = JSGInfinity.MOD_ID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public final class ClientSetup {
    private ClientSetup() {}

    /** Runs after JSG's own registration (the add-on loads after JSG), so its DHD renderer takes over. */
    @SubscribeEvent(priority = EventPriority.LOWEST)
    public static void registerRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.<StargateAbstractBaseBE<?, ?>>registerBlockEntityRenderer(JSGInfinity.BASE_BE.get(), InfinityGateRenderer::new);
        // JSG's Milky Way DHDs: JSG's own drawing, except for Infinity DHDs
        event.<DHDAbstractBE>registerBlockEntityRenderer(BlockEntityRegistry.DHD_MILKYWAY.get(), InfinityDHDRenderer::new);
    }
}
