package io.github.stargatecommand.jsginfinity.client;

import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.math.Axis;
import dev.tauri.jsg.api.client.model.AbstractOBJModel;
import dev.tauri.jsg.api.stargate.ChevronEnum;
import dev.tauri.jsg.api.stargate.network.address.symbol.SymbolTypeRegistry;
import dev.tauri.jsg.api.stargate.network.address.symbol.types.SymbolMilkyWayEnum;
import dev.tauri.jsg.loader.ElementEnum;
import dev.tauri.jsg.renderer.stargate.StargateMilkyWayRenderer;
import dev.tauri.jsg.stargate.animation.chevron.StargateChevronsState;
import io.github.stargatecommand.jsginfinity.JSGInfinity;
import it.unimi.dsi.fastutil.Pair;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.resources.ResourceLocation;

/**
 * Draws the gate with JSG's own Milky Way models and animation, in the colours of the cartoon:
 * each method follows JSG's Milky Way renderer step for step and binds the Infinity textures where
 * JSG binds its own. The event horizon is pale, as the show draws it.
 */
public class InfinityGateRenderer extends StargateMilkyWayRenderer {
    private static final ResourceLocation GATE = texture("infinity_gate");
    private static final ResourceLocation CHEVRON = texture("chevron");
    private static final ResourceLocation CHEVRON_LIT = texture("chevron_light");
    private static final ResourceLocation CHEVRON_OFF = texture("chevron_light_off");

    /** The horizon's base colour and its highlight, as JSG's ARGB pair: a pale blue-white whirlpool. */
    private static final int HORIZON = 0xFFA9BDDA;
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

    @Override
    public Pair<Integer, Integer> getEventHorizonColor() {
        return Pair.of(HORIZON, HORIZON_HIGHLIGHT);
    }
}
