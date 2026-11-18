package io.github.stargatecommand.jsginfinity.client;

import com.mojang.blaze3d.systems.RenderSystem;
import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import dev.tauri.jsg.api.blockstates.JSGProperties;
import dev.tauri.jsg.api.client.LoadersHolder;
import dev.tauri.jsg.api.client.model.AbstractOBJModel;
import dev.tauri.jsg.api.client.model.IModelLoader;
import dev.tauri.jsg.api.client.renderer.BlockRenderer;
import dev.tauri.jsg.api.raycaster.util.RaycasterVertex;
import dev.tauri.jsg.api.registry.BiomeOverlayRegistry;
import dev.tauri.jsg.api.stargate.network.address.StargateAddressDynamic;
import dev.tauri.jsg.api.stargate.network.address.symbol.SymbolInterface;
import dev.tauri.jsg.api.stargate.network.address.symbol.SymbolTypeRegistry;
import dev.tauri.jsg.api.stargate.network.address.symbol.types.SymbolMilkyWayEnum;
import dev.tauri.jsg.api.util.vectors.Vector3f;
import dev.tauri.jsg.blockentity.dialhomedevice.DHDAbstractBE;
import dev.tauri.jsg.loader.ElementEnum;
import dev.tauri.jsg.loader.texture.Texture;
import dev.tauri.jsg.registry.FluidRegistry;
import dev.tauri.jsg.renderer.dialhomedevice.DHDMilkyWayRenderer;
import dev.tauri.jsg.renderer.dialhomedevice.DHDMilkyWayRendererState;
import io.github.stargatecommand.jsginfinity.InfinityScreen;
import io.github.stargatecommand.jsginfinity.JSGInfinity;
import net.minecraft.client.renderer.LightTexture;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.client.renderer.texture.TextureAtlasSprite;
import net.minecraft.core.BlockPos;
import net.minecraft.nbt.CompoundTag;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraft.world.phys.Vec3;
import net.minecraftforge.fluids.FluidStack;
import org.joml.Matrix3f;
import org.joml.Matrix4f;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Draws every Milky Way DHD in place of JSG's own renderer. A JSG DHD is left entirely to JSG's
 * code.
 * <ul>
 * <li>The orange DHD is drawn by the same steps as JSG draws its own, with its own textures: the
 * body, console and key bases, and each key's light at the brightness JSG chose.</li>
 * <li>The Infinity DHD is a console of the add-on's own: a pedestal with a tilted screen, the keys
 * shown on the screen where {@link InfinityScreen} puts them, which is where JSG looks for a
 * pressed key.</li>
 * </ul>
 */
public class InfinityDHDRenderer extends DHDMilkyWayRenderer {
    private static final Pattern KEY_TEXTURE = Pattern.compile("(dhd_(?:button_light|brb)_[0-5])");
    private static final String SCREEN_LOOK = "infinity";

    /** The console's textures. */
    private static final ResourceLocation METAL = texture(SCREEN_LOOK, "metal");
    private static final ResourceLocation COLUMN = texture(SCREEN_LOOK, "column");
    private static final ResourceLocation GLASS = texture(SCREEN_LOOK, "screen");
    private static final ResourceLocation KEY = texture(SCREEN_LOOK, "key");
    private static final ResourceLocation GATE_ICON = texture(SCREEN_LOOK, "gate_icon");
    private static final ResourceLocation CHEVRON_MARK = texture(SCREEN_LOOK, "chevron_mark");
    private static final ResourceLocation LAMP = texture(SCREEN_LOOK, "lamp");

    /** The screen's colours, ARGB: keys and symbols at rest and lit, the dial button, the lamp. */
    private static final int KEY_IDLE = 0x9A2C5F86, KEY_LIT = 0xF05CD2FF;
    private static final int GLYPH_IDLE = 0xFF86C4EA, GLYPH_LIT = 0xFFFFFFFF;
    private static final int SLOT = 0x6A1E3E5A;
    private static final int BRB_IDLE = 0xFF5E9FCC, BRB_LIT = 0xFFB4F0FF;
    private static final int MARK_OFF = 0xFF2E4A66, MARK_LIT = 0xFF9EEBFF;
    private static final int LAMP_OFF = 0xFF27323F, LAMP_ON = 0xFF8EE8FF;
    /** The console's metal is tinted towards the gate's blue-grey. */
    private static final int METAL_TINT = 0xFFBCC8DC;
    /** The chevrons on the screen's gate light in a Milky Way gate's order: degrees clockwise from the top. */
    private static final int[] CHEVRON_ANGLES = {40, 80, 120, 240, 280, 320, 0, 160, 200};

    /** JSG's key-light textures and the ones that stand in for them, per look. */
    private final Map<String, ResourceLocation> keyTextures = new HashMap<>();
    /** The block of the DHD being drawn, and its look (its texture folder, or null for JSG's own); set for one render call. */
    private Block drawing;
    private String look;
    /**
     * The symbols each Infinity DHD has lit, in the order they lit. JSG tells the client only which
     * keys are lit, so the order is kept here as they light up.
     */
    private final Map<BlockPos, List<SymbolMilkyWayEnum>> dialled = new HashMap<>();
    /** Where the block is, before JSG moves and turns the pose for its own drawing. */
    private final Matrix4f blockPose = new Matrix4f();
    private final Matrix3f blockNormal = new Matrix3f();

    public InfinityDHDRenderer(BlockEntityRendererProvider.Context context) {
        super(context);
    }

    private static ResourceLocation texture(String look, String name) {
        return new ResourceLocation(JSGInfinity.MOD_ID, "textures/dhd/" + look + "/" + name + ".png");
    }

    private static String lookOf(Block block) {
        if (block == JSGInfinity.DHD_BLOCK.get()) return SCREEN_LOOK;
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
        blockPose.set(stack.last().pose());
        blockNormal.set(stack.last().normal());
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
        if (SCREEN_LOOK.equals(look)) return; // the whole console is drawn with the keys, below
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
        if (SCREEN_LOOK.equals(look)) {
            new Console(source, light).draw();
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

    /**
     * One drawing of the Infinity DHD's console. Every point is placed by JSG's own raycaster maths
     * from {@link InfinityScreen}'s frame, so the drawn keys are where the presses land.
     */
    private final class Console {
        private final MultiBufferSource source;
        private final int light;
        private final float rotation;
        private final Vector3f centre;

        Console(MultiBufferSource source, int light) {
            this.source = source;
            this.light = light;
            BlockPos pos = tileEntity.getBlockPos();
            BlockState state = level.getBlockState(pos);
            this.rotation = state.hasProperty(JSGProperties.ROTATION_PROPERTY) ? state.getValue(JSGProperties.ROTATION_PROPERTY) * -22.5f : 0f;
            this.centre = InfinityScreen.Raycaster.INSTANCE.getTranslation(level, pos);
        }

        private Vec3 place(Vector3f v) {
            return new RaycasterVertex(v.x, v.y, v.z).rotate(rotation).localToGlobal(BlockPos.ZERO, centre, 1f).getVec3();
        }

        void draw() {
            DHDMilkyWayRendererState state = rendererState;
            // the pedestal: a plinth, a step, a grooved column and a collar
            box(METAL, -0.42f, 0.42f, -0.30f, 0.30f, 0f, 0.07f);
            box(METAL, -0.34f, 0.34f, -0.24f, 0.24f, 0.07f, 0.13f);
            box(COLUMN, -0.22f, 0.22f, -0.16f, 0.16f, 0.13f, InfinityScreen.HEAD_BOTTOM - 0.06f);
            box(METAL, -0.30f, 0.30f, -0.22f, 0.22f, InfinityScreen.HEAD_BOTTOM - 0.06f, InfinityScreen.HEAD_BOTTOM);
            head();

            // the screen: glowing glass, the gate in the middle that dials, the keys either side
            float gl = InfinityScreen.GLASS_LENGTH, gx = InfinityScreen.GLASS_X;
            quad(RenderType.entityCutoutNoCull(GLASS), LightTexture.FULL_BRIGHT, 0xFFFFFFFF, glassNormal(),
                    InfinityScreen.onGlass(-gx, gl, 0), InfinityScreen.onGlass(gx, gl, 0),
                    InfinityScreen.onGlass(gx, 0, 0), InfinityScreen.onGlass(-gx, 0, 0));

            CompoundTag notebookPage = getNoteBookPage();
            for (InfinityScreen.Key key : InfinityScreen.keys()) {
                boolean lit = state.isButtonActive(key.symbol());
                List<Vector3f> c = key.corners(InfinityScreen.Raycaster.LIFT);
                glow(KEY, lit ? KEY_LIT : KEY_IDLE, c.get(0), c.get(1), c.get(2), c.get(3));
                Vector3f tint = getColorByAddress(state, notebookPage, SymbolTypeRegistry.MILKYWAY, key.symbol());
                glyph(key.symbol(), key.u(), key.w(), 0.072f, lit ? GLYPH_LIT : tinted(GLYPH_IDLE, tint));
            }

            SymbolMilkyWayEnum brb = SymbolMilkyWayEnum.values()[0];
            for (SymbolMilkyWayEnum s : SymbolMilkyWayEnum.values()) if (s.brb()) brb = s;
            boolean open = state.brbActive || state.isButtonActive(brb);
            square(GATE_ICON, open ? BRB_LIT : BRB_IDLE, 0, InfinityScreen.BRB_W, InfinityScreen.BRB_R, 0, 0.003f);

            List<SymbolMilkyWayEnum> order = dialOrder(state);
            int count = order.size();
            for (int i = 0; i < CHEVRON_ANGLES.length; i++) {
                double a = Math.toRadians(CHEVRON_ANGLES[i]);
                float r = InfinityScreen.BRB_R + 0.026f;
                square(CHEVRON_MARK, i < count ? MARK_LIT : MARK_OFF, (float) (r * Math.sin(a)),
                        (float) (InfinityScreen.BRB_W + r * Math.cos(a)), 0.018f, (float) a, 0.003f);
            }

            // the address dialled so far, along the top of the glass
            for (int i = 0; i < 9; i++) {
                float u = (i - 4) * InfinityScreen.STRIP_PITCH, w = InfinityScreen.STRIP_W, h = InfinityScreen.STRIP_SIZE / 2;
                glow(KEY, SLOT, InfinityScreen.onGlass(u - h, w + h, 0.002f), InfinityScreen.onGlass(u + h, w + h, 0.002f),
                        InfinityScreen.onGlass(u + h, w - h, 0.002f), InfinityScreen.onGlass(u - h, w - h, 0.002f));
                if (i < count) glyph(order.get(i), u, w, 0.07f, GLYPH_LIT);
            }

            // the lamp that shows a control crystal is in
            boolean crystal = !tileEntity.getItemStackHandler().getStackInSlot(0).isEmpty();
            square(LAMP, crystal ? LAMP_ON : LAMP_OFF, 0, InfinityScreen.LAMP_W, InfinityScreen.LAMP_R, 0, 0.003f);
        }

        /** The lit symbols in the order they lit; the ones lit before this DHD came into view go first, in JSG's order if it sent one. */
        private List<SymbolMilkyWayEnum> dialOrder(DHDMilkyWayRendererState state) {
            BlockPos pos = tileEntity.getBlockPos().immutable();
            List<SymbolMilkyWayEnum> list = dialled.computeIfAbsent(pos, p -> new ArrayList<>());
            list.removeIf(symbol -> !state.isButtonActive(symbol));
            StargateAddressDynamic sent = state.addressDialed;
            if (sent != null) {
                for (SymbolInterface symbol : sent) {
                    if (symbol instanceof SymbolMilkyWayEnum mw && state.isButtonActive(mw) && !list.contains(mw)) list.add(mw);
                }
            }
            for (InfinityScreen.Key key : InfinityScreen.keys()) {
                if (state.isButtonActive(key.symbol()) && !list.contains(key.symbol())) list.add(key.symbol());
            }
            if (list.isEmpty()) dialled.remove(pos);
            return list;
        }

        /** The head: a wedge whose top slopes towards the player, a bezel round the glass. */
        private void head() {
            float x = InfinityScreen.HEAD_X, back = InfinityScreen.HEAD_BACK, front = InfinityScreen.HEAD_FRONT;
            float bottom = InfinityScreen.HEAD_BOTTOM;
            float tb = InfinityScreen.top(back), tf = InfinityScreen.top(front);
            RenderType metal = RenderType.entityCutoutNoCull(METAL);
            quad(metal, light, METAL_TINT, v(0, 0, -1), v(-x, front, bottom), v(x, front, bottom), v(x, back, bottom), v(-x, back, bottom));
            quad(metal, light, METAL_TINT, v(0, 1, 0), v(-x, front, tf), v(x, front, tf), v(x, front, bottom), v(-x, front, bottom));
            quad(metal, light, METAL_TINT, v(0, -1, 0), v(x, back, tb), v(-x, back, tb), v(-x, back, bottom), v(x, back, bottom));
            quad(metal, light, METAL_TINT, v(-1, 0, 0), v(-x, back, tb), v(-x, front, tf), v(-x, front, bottom), v(-x, back, bottom));
            quad(metal, light, METAL_TINT, v(1, 0, 0), v(x, front, tf), v(x, back, tb), v(x, back, bottom), v(x, front, bottom));
            // the bezel: four strips of the top round the glass, and the glass's edges below them
            float gx = InfinityScreen.GLASS_X, gb = InfinityScreen.GLASS_BACK, gf = InfinityScreen.GLASS_FRONT;
            Vector3f up = glassNormal();
            topQuad(metal, up, -x, x, back, gb);
            topQuad(metal, up, -x, x, gf, front);
            topQuad(metal, up, -x, -gx, gb, gf);
            topQuad(metal, up, gx, x, gb, gf);
            float drop = InfinityScreen.GLASS_DROP;
            float tgb = InfinityScreen.top(gb), tgf = InfinityScreen.top(gf);
            quad(metal, light, METAL_TINT, v(0, 1, 0), v(-gx, gb, tgb), v(gx, gb, tgb), v(gx, gb, tgb - drop), v(-gx, gb, tgb - drop));
            quad(metal, light, METAL_TINT, v(0, -1, 0), v(-gx, gf, tgf), v(gx, gf, tgf), v(gx, gf, tgf - drop), v(-gx, gf, tgf - drop));
            quad(metal, light, METAL_TINT, v(1, 0, 0), v(-gx, gb, tgb), v(-gx, gf, tgf), v(-gx, gf, tgf - drop), v(-gx, gb, tgb - drop));
            quad(metal, light, METAL_TINT, v(-1, 0, 0), v(gx, gb, tgb), v(gx, gf, tgf), v(gx, gf, tgf - drop), v(gx, gb, tgb - drop));
        }

        private void topQuad(RenderType type, Vector3f normal, float x0, float x1, float y0, float y1) {
            quad(type, light, METAL_TINT, normal, v(x0, y0, InfinityScreen.top(y0)), v(x1, y0, InfinityScreen.top(y0)),
                    v(x1, y1, InfinityScreen.top(y1)), v(x0, y1, InfinityScreen.top(y1)));
        }

        private void box(ResourceLocation texture, float x0, float x1, float y0, float y1, float z0, float z1) {
            RenderType type = RenderType.entityCutoutNoCull(texture);
            int c = METAL_TINT;
            quad(type, light, c, v(0, 0, 1), v(x0, y1, z1), v(x1, y1, z1), v(x1, y0, z1), v(x0, y0, z1));
            quad(type, light, c, v(0, 0, -1), v(x0, y0, z0), v(x1, y0, z0), v(x1, y1, z0), v(x0, y1, z0));
            quad(type, light, c, v(0, 1, 0), v(x0, y1, z1), v(x1, y1, z1), v(x1, y1, z0), v(x0, y1, z0));
            quad(type, light, c, v(0, -1, 0), v(x1, y0, z1), v(x0, y0, z1), v(x0, y0, z0), v(x1, y0, z0));
            quad(type, light, c, v(-1, 0, 0), v(x0, y0, z1), v(x0, y1, z1), v(x0, y1, z0), v(x0, y0, z0));
            quad(type, light, c, v(1, 0, 0), v(x1, y1, z1), v(x1, y0, z1), v(x1, y0, z0), v(x1, y1, z0));
        }

        /** A symbol's own picture, from JSG, square on the glass round (u, w). */
        private void glyph(SymbolInterface symbol, float u, float w, float size, int argb) {
            ResourceLocation icon = symbol.getIconResource(tileEntity.getPointOfOrigin());
            if (icon == null) return;
            square(icon, argb, u, w, size / 2, 0, 0.004f);
        }

        /** A square picture on the glass round (u, w), half as wide as given, turned clockwise by angle. */
        private void square(ResourceLocation texture, int argb, float u, float w, float half, float angle, float lift) {
            float cos = (float) Math.cos(angle), sin = (float) Math.sin(angle);
            float[][] corners = {{-half, half}, {half, half}, {half, -half}, {-half, -half}}; // top left first, as seen
            Vector3f[] p = new Vector3f[4];
            for (int i = 0; i < 4; i++) {
                float du = corners[i][0] * cos + corners[i][1] * sin, dw = -corners[i][0] * sin + corners[i][1] * cos;
                p[i] = InfinityScreen.onGlass(u + du, w + dw, lift);
            }
            glow(texture, argb, p[0], p[1], p[2], p[3]);
        }

        private void glow(ResourceLocation texture, int argb, Vector3f a, Vector3f b, Vector3f c, Vector3f d) {
            quad(RenderType.entityTranslucent(texture), LightTexture.FULL_BRIGHT, argb, glassNormal(), a, b, c, d);
        }

        private Vector3f glassNormal() {
            float slope = 0.55f; // InfinityScreen's top falls this much per block towards the player
            float len = (float) Math.sqrt(1 + slope * slope);
            return v(0, slope / len, 1 / len);
        }

        /** A textured quad, its corners top left, top right, bottom right, bottom left, in the raycaster's frame. */
        private void quad(RenderType type, int packedLight, int argb, Vector3f normal, Vector3f a, Vector3f b, Vector3f c, Vector3f d) {
            VertexConsumer vc = source.getBuffer(type);
            Vec3 pa = place(a);
            Vec3 n = place(new Vector3f(a.x + normal.x, a.y + normal.y, a.z + normal.z)).subtract(pa).normalize();
            vertex(vc, pa, 0, 0, argb, packedLight, n);
            vertex(vc, place(b), 1, 0, argb, packedLight, n);
            vertex(vc, place(c), 1, 1, argb, packedLight, n);
            vertex(vc, place(d), 0, 1, argb, packedLight, n);
        }

        private void vertex(VertexConsumer vc, Vec3 p, float u, float v, int argb, int packedLight, Vec3 n) {
            vc.vertex(blockPose, (float) p.x, (float) p.y, (float) p.z)
                    .color((argb >> 16) & 0xFF, (argb >> 8) & 0xFF, argb & 0xFF, (argb >>> 24) & 0xFF)
                    .uv(u, v).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(packedLight)
                    .normal(blockNormal, (float) n.x, (float) n.y, (float) n.z).endVertex();
        }
    }

    private static Vector3f v(float x, float y, float z) {
        return new Vector3f(x, y, z);
    }

    private static int tinted(int argb, Vector3f tint) {
        int r = Math.min(255, (int) (((argb >> 16) & 0xFF) * tint.x));
        int g = Math.min(255, (int) (((argb >> 8) & 0xFF) * tint.y));
        int b = Math.min(255, (int) ((argb & 0xFF) * tint.z));
        return (argb & 0xFF000000) | (r << 16) | (g << 8) | b;
    }
}
