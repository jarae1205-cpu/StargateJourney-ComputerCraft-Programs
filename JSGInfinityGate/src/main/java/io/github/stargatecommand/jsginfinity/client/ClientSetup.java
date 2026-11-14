package io.github.stargatecommand.jsginfinity.client;

import dev.tauri.jsg.blockentity.stargate.StargateAbstractBaseBE;
import io.github.stargatecommand.jsginfinity.JSGInfinity;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = JSGInfinity.MOD_ID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public final class ClientSetup {
    private ClientSetup() {}

    @SubscribeEvent
    public static void registerRenderers(EntityRenderersEvent.RegisterRenderers event) {
        event.<StargateAbstractBaseBE<?, ?>>registerBlockEntityRenderer(JSGInfinity.BASE_BE.get(), InfinityGateRenderer::new);
    }
}
