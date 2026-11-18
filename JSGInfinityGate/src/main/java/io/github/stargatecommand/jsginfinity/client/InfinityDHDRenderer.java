package io.github.stargatecommand.jsginfinity.client;

import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.blaze3d.vertex.PoseStack;
import dev.tauri.jsg.api.client.LoadersHolder;
import dev.tauri.jsg.api.client.model.AbstractOBJModel;
import dev.tauri.jsg.api.client.model.IModelLoader;
import dev.tauri.jsg.api.client.renderer.BlockRenderer;
import dev.tauri.jsg.api.registry.BiomeOverlayRegistry;
import dev.tauri.jsg.api.stargate.network.address.symbol.SymbolTypeRegistry;
import dev.tauri.jsg.api.stargate.network.address.symbol.types.SymbolMilkyWayEnum;
import dev.tauri.jsg.api.util.vectors.Vector3f;
import dev.tauri.jsg.blockentity.dialhomedevice.DHDAbstractBE;
import dev.tauri.jsg.loader.ElementEnum;
import dev.tauri.jsg.loader.texture.Texture;
import dev.tauri.jsg.registry.FluidRegistry;
import dev.tauri.jsg.renderer.dialhomedevice.DHDMilkyWayRenderer;
import dev.tauri.jsg.renderer.dialhomedevice.DHDMilkyWayRendererState;
import io.github.stargatecommand.jsginfinity.JSGInfinity;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.renderer.texture.TextureAtlasSprite;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraftforge.fluids.FluidStack;

import java.util.HashMap;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Draws every Milky Way DHD in place of JSG's own renderer. A JSG DHD is left entirely to JSG's
 * code. The add-on's DHDs (Infinity and orange) are drawn by the same steps as JSG draws its own,
 * with their own textures: the body, console and key bases, and each key's light at the
 * brightness JSG chose.
 */
public class InfinityDHDRenderer extends DHDMilkyWayRenderer {
    private static final Pattern KEY_TEXTURE = Pattern.compile("(dhd_(?:button_light|brb)_[0-5])");

    /** JSG's key-light textures and the ones that stand in for them, per look. */
    private final Map<String, ResourceLocation> keyTextures = new HashMap<>();
    /** The block of the DHD being drawn, and its look (its texture folder, or null for JSG's own); set for one render call. */
    private Block drawing;
    private String look;

    public InfinityDHDRenderer(BlockEntityRendererProvider.Context context) {
        super(context);
    }

    private static ResourceLocation texture(String look, String name) {
        return new ResourceLocation(JSGInfinity.MOD_ID, "textures/dhd/" + look + "/" + name + ".png");
    }

    private static String lookOf(Block block) {
        if (block == JSGInfinity.DHD_BLOCK.get()) return "infinity";
        if (block == JSGInfinity.ORANGE_DHD_BLOCK.get()) return "orange";
        return null;
    }

    /** What JSG's texture binding does: the models draw with the active texture. */
    private static void bind(ResourceLocation texture) {
        AbstractOBJModel.setActiveTexture(texture);
        RenderSystem.setShaderTexture(0, texture);
    }

    @Override
    public void render(DHDAbstractBE dhd, float partialTicks, PoseStack stack, MultiBufferSource source, int light, int overlay) {
        Level level = dhd.getLevel();
        drawing = level != null ? level.getBlockState(dhd.getBlockPos()).getBlock() : null;
        look = lookOf(drawing);
        try {
            super.render(dhd, partialTicks, stack, source, light, overlay);
        } finally {
            drawing = null;
            look = null;
        }
    }

    /** JSG draws a DHD only where its own block stands; the add-on's DHD blocks count too. */
    @Override
    public Block getDHDBlock() {
        return look != null ? drawing : super.getDHDBlock();
    }

    @Override
    public void renderDHD(PoseStack stack, MultiBufferSource source, int light, int overlay) {
        if (look == null) {
            super.renderDHD(stack, source, light, overlay);
            return;
        }
        BiomeOverlayRegistry.BiomeOverlayInstance biome = rendererState.getBiomeOverlay();
        // the parts drawn with the DHD's own texture: this look's
        bind(texture(look, "dhd_base"));
        ElementEnum.MILKYWAY_DHD_BASE.render(stack, source, light, overlay);
        ElementEnum.MILKYWAY_DHD_BUTTON_CONSOLE.render(stack, source, light, overlay);
        ElementEnum.MILKYWAY_DHD_CRYSTAL_HOLDER.render(stack, source, light, overlay);
        ElementEnum.MILKYWAY_DHD_UPGRADE_COVER.render(stack, source, light, overlay);
        // the crystals and the fuel tank, with JSG's own textures, as JSG draws them
        ElementEnum.MILKYWAY_DHD_UPGRADE_CRYSTAL.bindTexture(biome).render(stack, source, light, overlay);
        ElementEnum.MILKYWAY_DHD_CRYSTALS.bindTexture(biome).render(stack, source, light, overlay);
        if (!tileEntity.getItemStackHandler().getStackInSlot(0).isEmpty()) {
            ElementEnum.MILKYWAY_DHD_CONTROL_CRYSTAL.render(stack, source, light, overlay);
        }
        ElementEnum.MILKYWAY_DHD_FLUID_TANK_BASE.bindTexture(biome).render(stack, source, light, overlay);
        RenderSystem.enableBlend();
        TextureAtlasSprite fluid = BlockRenderer.getFluidTexture(
                new FluidStack(FluidRegistry.MOLTEN_NAQUADAH_REFINED.still.get(), 1000), BlockRenderer.FluidTextureType.STILL);
        if (fluid != null) {
            Texture.bindTextureWithMc(fluid.atlasLocation());
            ElementEnum.MILKYWAY_DHD_FLUID_TANK_FLUID.render(stack, source, light, overlay, fluid);
        }
        ElementEnum.MILKYWAY_DHD_FLUID_TANK_GLASS.bindTexture(biome).render(stack, source, light, overlay);
        RenderSystem.disableBlend();
    }

    @Override
    public void renderSymbols(PoseStack stack, MultiBufferSource source, int light, int overlay) {
        if (look == null) {
            super.renderSymbols(stack, source, light, overlay);
            return;
        }
        ResourceLocation base = texture(look, "dhd_base");
        DHDMilkyWayRendererState state = rendererState;
        BiomeOverlayRegistry.BiomeOverlayInstance biome = state.getBiomeOverlay();
        CompoundTag notebookPage = getNoteBookPage();
        IModelLoader models = LoadersHolder.JSG_HOLDER.model();
        for (SymbolMilkyWayEnum symbol : SymbolMilkyWayEnum.values()) {
            stack.pushPose();
            // JSG tints the keys of an address held in a notebook; kept as it is
            Vector3f tint = getColorByAddress(state, notebookPage, SymbolTypeRegistry.MILKYWAY, symbol);
            ResourceLocation keyLight = keyTexture(state.getButtonTexture(symbol, biome));
            if (symbol.origin()) {
                bind(base);
                models.getModel(models.getModelResource("milkyway/dhd/buttons/4_base.obj"))
                        .render(stack, source, light, overlay, false, tint.x, tint.y, tint.z, 1f, false);
                bind(keyLight);
                models.getModel(models.getModelResource("milkyway/dhd/buttons/4.obj"))
                        .render(stack, source, light, overlay, state.isButtonActive(symbol), tint.x, tint.y, tint.z, 1f, false);
            }
            bind(keyLight);
            symbol.getModel(tileEntity.getSymbolType().getPointOfOriginType(), tileEntity.getPointOfOrigin(), "dhd_light.obj")
                    .render(stack, source, light, overlay, state.isButtonActive(symbol), tint.x, tint.y, tint.z, 1f, false);
            if (symbol.brb()) RenderSystem.setShaderColor(1f, 1f, 1f, 1f);
            bind(base);
            symbol.getModel(tileEntity.getSymbolType().getPointOfOriginType(), tileEntity.getPointOfOrigin(), "dhd.obj")
                    .render(stack, source, light, overlay, false, tint.x, tint.y, tint.z, 1f, false);
            stack.popPose();
        }
    }

    /** This look's texture for one of JSG's key-light textures: the same key, the same brightness. */
    private ResourceLocation keyTexture(ResourceLocation jsgTexture) {
        String current = look;
        return keyTextures.computeIfAbsent(current + "|" + jsgTexture, k -> {
            Matcher m = KEY_TEXTURE.matcher(jsgTexture.getPath());
            return m.find() ? texture(current, m.group(1)) : jsgTexture;
        });
    }
}
