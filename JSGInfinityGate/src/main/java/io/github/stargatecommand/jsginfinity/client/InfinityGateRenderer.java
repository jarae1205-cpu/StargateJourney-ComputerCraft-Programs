package io.github.stargatecommand.jsginfinity.client;

import com.mojang.blaze3d.platform.NativeImage;
import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;
import dev.tauri.jsg.api.client.LoadersHolder;
import dev.tauri.jsg.api.client.model.AbstractOBJModel;
import dev.tauri.jsg.api.client.texture.ITexture;
import dev.tauri.jsg.api.client.texture.ITextureLoader;
import dev.tauri.jsg.api.registry.BiomeOverlayRegistry;
import dev.tauri.jsg.api.stargate.ChevronEnum;
import dev.tauri.jsg.api.stargate.network.address.symbol.SymbolTypeRegistry;
import dev.tauri.jsg.api.stargate.network.address.symbol.types.SymbolMilkyWayEnum;
import dev.tauri.jsg.loader.ElementEnum;
import dev.tauri.jsg.loader.texture.Texture;
import dev.tauri.jsg.renderer.stargate.StargateAbstractRenderer;
import dev.tauri.jsg.renderer.stargate.StargateMilkyWayRenderer;
import dev.tauri.jsg.stargate.animation.chevron.StargateChevronsState;
import io.github.stargatecommand.jsginfinity.JSGInfinity;
import it.unimi.dsi.fastutil.Pair;
import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.LightTexture;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.resources.ResourceLocation;
import org.joml.Matrix3f;
import org.joml.Matrix4f;

import java.io.IOException;
import java.io.InputStream;

/**
 * Draws the gate with JSG's own Milky Way models and animation, in the colours of the cartoon:
 * each method follows JSG's Milky Way renderer step for step and binds the Infinity textures where
 * JSG binds its own. The event horizon is white, with a blue swirl turning over it once it settles,
 * as in Carter's Addon Pack; the iris closes into a pale spiral.
 */
public class InfinityGateRenderer extends StargateMilkyWayRenderer {
    private static final ResourceLocation GATE = texture("infinity_gate");
    private static final ResourceLocation CHEVRON = texture("chevron");
    private static final ResourceLocation CHEVRON_LIT = texture("chevron_light");
    private static final ResourceLocation CHEVRON_OFF = texture("chevron_light_off");
    private static final ResourceLocation IRIS = texture("iris_blade");
    private static final ResourceLocation SPIRAL = texture("wormhole_spiral");
    /**
     * Stands in for JSG's iris texture while an Infinity gate draws its iris. JSG's loader holds
     * its own Texture class, so the stand-in is one, made from the Infinity iris when first needed.
     */
    private static Texture irisTexture;
    /** How fast the swirl turns, in degrees per tick. */
    private static final float SPIRAL_SPEED = 1.0f;

    /** The horizon's base colour and its highlight, as JSG's ARGB pair: nearly white, a touch of blue. */
    private static final int HORIZON = 0xFFE4F4FB;
    private static final int HORIZON_HIGHLIGHT = 0xFFFFFFFF;

    public InfinityGateRenderer(BlockEntityRendererProvider.Context context) {
        super(context);
    }

    private static ResourceLocation texture(String name) {
        return new ResourceLocation(JSGInfinity.MOD_ID, "textures/gate/" + name + ".png");
    }

    /** What JSG's texture binding does: the models draw with the active texture. */
    private static void bind(ResourceLocation texture) {
        AbstractOBJModel.setActiveTexture(texture);
        RenderSystem.setShaderTexture(0, texture);
    }

    @Override
    protected void renderGate() {
        stack.pushPose();
        bind(GATE);
        ElementEnum.MILKYWAY_GATE.render(stack, source, combinedLight);
        stack.popPose();
        renderRing();
        renderChevrons();
    }

    @Override
    protected void renderRing() {
        stack.pushPose();
        float angle = (float) tileEntity.getDialingManager().getSpinHelper().apply(level.getGameTime() + partialTicks, true);
        // JSG's RING_LOC keeps the ring's centre with its y and z swapped
        stack.translate(RING_LOC.x, RING_LOC.z, RING_LOC.y);
        stack.mulPose(Axis.ZP.rotationDegrees(-angle));
        stack.translate(-RING_LOC.x, -RING_LOC.z, -RING_LOC.y);
        bind(GATE);
        ElementEnum.MILKYWAY_RING.render(stack, source, combinedLight);
        // the point of origin on the ring, drawn in the ring's colours
        ((SymbolMilkyWayEnum) SymbolTypeRegistry.MILKYWAY.getOrigin())
                .getModel(tileEntity.getStargateType(), tileEntity.getPointOfOrigin(), "stargate.obj")
                .render(stack, source, combinedLight);
        stack.popPose();
    }

    /**
     * JSG draws each chevron twice: once as it is (lightPass false), then its light, glowing
     * when locked (lightPass true).
     */
    @Override
    protected void renderChevron(ChevronEnum chevron, StargateChevronsState.ChevronState unused, float brightness, boolean lightPass) {
        stack.pushPose();
        stack.mulPose(Axis.ZP.rotationDegrees(chevron.rotation));
        StargateChevronsState.ChevronState state = tileEntity.getStateManager().getChevronsState().get(chevron);
        boolean lit = lightPass && state.isLocked();
        float offset = state.getOffset(partialTicks, 1.5f);
        bind(lightPass ? (state.getState() < 1f ? CHEVRON_OFF : CHEVRON_LIT) : CHEVRON);

        stack.pushPose();
        stack.translate(0f, offset, 0f);
        ElementEnum.MILKYWAY_CHEVRON_LIGHT.render(stack, source, combinedLight, lit, brightness);
        stack.translate(0f, -2f * offset, 0f);
        ElementEnum.MILKYWAY_CHEVRON_MOVING.render(stack, source, combinedLight, lit, brightness);
        stack.popPose();

        if (!lightPass) {
            bind(GATE);
            ElementEnum.MILKYWAY_CHEVRON_FRAME.render(stack, source, combinedLight);
            ElementEnum.MILKYWAY_CHEVRON_BACK.render(stack, source, combinedLight);
        }
        stack.popPose();
    }

    /**
     * JSG's iris, drawn with the Infinity blades. JSG looks its iris texture up in its texture
     * loader for each draw, so for this one draw the Infinity texture stands under JSG's key;
     * other gates keep JSG's iris.
     */
    @Override
    public void renderIris(boolean renderOnly) {
        ITextureLoader loader = LoadersHolder.JSG_HOLDER.texture();
        ResourceLocation key = ElementEnum.IRIS.getBiomeTextureResourceMap().get(BiomeOverlayRegistry.NORMAL);
        ITexture jsg = key != null ? loader.getTexture(key) : null;
        Texture infinity = irisTexture();
        if (jsg == null || infinity == null) {
            super.renderIris(renderOnly);
            return;
        }
        loader.putTexture(key, infinity);
        try {
            super.renderIris(renderOnly);
        } finally {
            loader.putTexture(key, jsg);
        }
    }

    private static Texture irisTexture() {
        if (irisTexture == null) {
            try (InputStream in = Minecraft.getInstance().getResourceManager().open(IRIS)) {
                irisTexture = new Texture(NativeImage.read(in), IRIS);
            } catch (IOException e) {
                return null; // JSG's own iris, then
            }
        }
        return irisTexture;
    }

    /** JSG draws the horizon this far in front of the gate's centre, and this wide. */
    private static final float HORIZON_DEPTH = 0.06f, HORIZON_RADIUS = 3.790975f;

    /** JSG's event horizon, then, once it has settled, the blue swirl over it. */
    @Override
    protected void renderKawoosh() {
        // JSG may leave its own moves (and a scale) on the stack: draw the swirl from where it started
        stack.pushPose();
        super.renderKawoosh();
        stack.popPose();
        if (rendererState.vortexState != StargateAbstractRenderer.EnumVortexState.STILL) return;
        float r = HORIZON_RADIUS;
        stack.pushPose();
        stack.translate(0f, 0f, HORIZON_DEPTH + 0.015f); // just in front of the horizon
        stack.mulPose(Axis.ZP.rotationDegrees((level.getGameTime() % 3600 + partialTicks) * SPIRAL_SPEED));
        Matrix4f pose = stack.last().pose();
        Matrix3f normal = stack.last().normal();
        VertexConsumer vc = source.getBuffer(RenderType.entityTranslucent(SPIRAL));
        // the render type draws both faces
        vertex(vc, pose, normal, -r, -r, 0f, 0f, 1f);
        vertex(vc, pose, normal, r, -r, 0f, 1f, 1f);
        vertex(vc, pose, normal, r, r, 0f, 1f, 0f);
        vertex(vc, pose, normal, -r, r, 0f, 0f, 0f);
        stack.popPose();
    }

    private void vertex(VertexConsumer vc, Matrix4f pose, Matrix3f normal, float x, float y, float z, float u, float v) {
        // the wormhole gives its own light, so the swirl is as bright in the dark as in the day
        vc.vertex(pose, x, y, z).color(255, 255, 255, 255).uv(u, v).overlayCoords(OverlayTexture.NO_OVERLAY)
                .uv2(LightTexture.FULL_BRIGHT).normal(normal, 0f, 0f, 1f).endVertex();
    }

    @Override
    public Pair<Integer, Integer> getEventHorizonColor() {
        return Pair.of(HORIZON, HORIZON_HIGHLIGHT);
    }
}
