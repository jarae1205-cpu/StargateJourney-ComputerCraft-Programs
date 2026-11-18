package io.github.stargatecommand.sginfinity.client;

import io.github.stargatecommand.sginfinity.CommonProxy;
import io.github.stargatecommand.sginfinity.InfinityBaseTE;
import io.github.stargatecommand.sginfinity.SGInfinity;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.block.model.ModelResourceLocation;
import net.minecraft.client.resources.IReloadableResourceManager;
import net.minecraftforge.client.event.ModelRegistryEvent;
import net.minecraftforge.client.model.ModelLoader;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.fml.client.registry.ClientRegistry;
import net.minecraftforge.fml.common.eventhandler.SubscribeEvent;

public class ClientProxy extends CommonProxy {

    @Override
    public void preInit() {
        // SGCraft's own gate renderer, with the Infinity textures in place while it draws
        ClientRegistry.bindTileEntitySpecialRenderer(InfinityBaseTE.class, new InfinityGateRenderer());
        if (Minecraft.getMinecraft().getResourceManager() instanceof IReloadableResourceManager)
            ((IReloadableResourceManager) Minecraft.getMinecraft().getResourceManager())
                    .registerReloadListener(resourceManager -> InfinityTextures.forget());
        MinecraftForge.EVENT_BUS.register(this);
    }

    @SubscribeEvent
    public void registerModels(ModelRegistryEvent event) {
        ModelLoader.setCustomModelResourceLocation(SGInfinity.infinityBaseItem, 0,
                new ModelResourceLocation(SGInfinity.infinityBase.getRegistryName(), "inventory"));
    }
}
