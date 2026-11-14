package io.github.stargatecommand.chevron7.client;

import io.github.stargatecommand.chevron7.Chevron7;
import net.minecraft.client.Minecraft;
import net.minecraft.core.BlockPos;
import net.minecraftforge.api.distmarker.Dist;
import net.minecraftforge.client.event.EntityRenderersEvent;
import net.minecraftforge.eventbus.api.SubscribeEvent;
import net.minecraftforge.fml.common.Mod;

@Mod.EventBusSubscriber(modid = Chevron7.MOD_ID, bus = Mod.EventBusSubscriber.Bus.MOD, value = Dist.CLIENT)
public final class ClientHooks
{
	private ClientHooks() {}

	@SubscribeEvent
	public static void registerRenderers(EntityRenderersEvent.RegisterRenderers event)
	{
		event.registerBlockEntityRenderer(Chevron7.STARGATE_ENTITY.get(), StargateRenderer::new);
		event.registerBlockEntityRenderer(Chevron7.DHD_ENTITY.get(), DHDRenderer::new);
	}

	public static void openDhd(BlockPos pos)
	{
		Minecraft.getInstance().setScreen(new DHDScreen(pos));
	}
}
