package io.github.stargatecommand.sginfinity.client;

import java.awt.Color;
import java.awt.image.BufferedImage;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import net.minecraft.client.Minecraft;
import net.minecraft.client.renderer.texture.DynamicTexture;
import net.minecraft.client.renderer.texture.ITextureObject;
import net.minecraft.client.renderer.texture.TextureManager;
import net.minecraft.client.renderer.texture.TextureUtil;
import net.minecraft.client.resources.IResource;
import net.minecraft.util.ResourceLocation;
import net.minecraftforge.fml.relauncher.ReflectionHelper;

/**
 * The Infinity gate's textures, made from SGCraft's own Milky Way gate textures as the game loads
 * them: grey stone turned pale with dark grooves, orange chevron lights turned lime-yellow, and a
 * pale blue-white event horizon, as in the cartoon. Nothing of SGCraft's is copied into this
 * mod; whatever SGCraft (or a resource pack) draws its gate with is what gets recoloured.
 *
 * While an Infinity gate is drawn, these stand in for SGCraft's textures under SGCraft's own
 * names in the texture manager, and SGCraft's come straight back afterwards.
 */
public final class InfinityTextures {

    private InfinityTextures() {}

    /** SGCraft's textures that a Milky Way gate is drawn with, under textures/tileentity/. */
    private static final String[] NAMES = {
            "milkyway/stargate", "milkyway/ring", "milkyway/chevron", "milkyway/glyphs", "milkyway/symbols",
            "milkyway/detail", "milkyway/light", "milkyway/slats", "milkyway/iris", "eventhorizon", "eventhorizonhd",
    };

    private static final int[] INK = {34, 38, 52};
    private static final int[] PALE = {222, 228, 238};
    private static final float LIME_HUE = 70 / 360F;

    private static Map<ResourceLocation, ITextureObject> infinity;
    private static final Map<ResourceLocation, ITextureObject> displaced = new HashMap<>();
    private static Map<ResourceLocation, ITextureObject> managerMap;

    @SuppressWarnings("unchecked")
    private static Map<ResourceLocation, ITextureObject> textureMap(TextureManager manager) {
        if (managerMap == null)
            managerMap = (Map<ResourceLocation, ITextureObject>) ReflectionHelper.getPrivateValue(
                    TextureManager.class, manager, "mapTextureObjects", "field_110585_a");
        return managerMap;
    }

    /** Puts the Infinity textures in place of SGCraft's. */
    public static void swapIn() {
        TextureManager manager = Minecraft.getMinecraft().getTextureManager();
        if (infinity == null)
            infinity = load();
        Map<ResourceLocation, ITextureObject> map = textureMap(manager);
        for (Map.Entry<ResourceLocation, ITextureObject> entry : infinity.entrySet()) {
            displaced.put(entry.getKey(), map.get(entry.getKey()));
            map.put(entry.getKey(), entry.getValue());
        }
    }

    /** Gives SGCraft its own textures back. */
    public static void swapOut() {
        if (displaced.isEmpty())
            return;
        Map<ResourceLocation, ITextureObject> map = textureMap(Minecraft.getMinecraft().getTextureManager());
        for (Map.Entry<ResourceLocation, ITextureObject> entry : displaced.entrySet()) {
            if (entry.getValue() == null)
                map.remove(entry.getKey());
            else
                map.put(entry.getKey(), entry.getValue());
        }
        displaced.clear();
    }

    /** Resources were reloaded (F3+T, a new resource pack): make them again next time. */
    public static void forget() {
        if (infinity != null)
            for (ITextureObject texture : infinity.values())
                TextureUtil.deleteTexture(texture.getGlTextureId());
        infinity = null;
    }

    private static Map<ResourceLocation, ITextureObject> load() {
        Map<ResourceLocation, ITextureObject> textures = new HashMap<>();
        for (String name : NAMES) {
            ResourceLocation location = new ResourceLocation("sgcraft", "textures/tileentity/" + name + ".png");
            try (IResource resource = Minecraft.getMinecraft().getResourceManager().getResource(location)) {
                BufferedImage image = TextureUtil.readBufferedImage(resource.getInputStream());
                textures.put(location, new DynamicTexture(recolour(image, name.startsWith("eventhorizon"))));
            } catch (IOException e) {
                // this version of SGCraft doesn't have that texture: its own is used
            }
        }
        return textures;
    }

    /** The Infinity palette, pixel by pixel. */
    static BufferedImage recolour(BufferedImage source, boolean horizon) {
        int w = source.getWidth(), h = source.getHeight();
        BufferedImage out = new BufferedImage(w, h, BufferedImage.TYPE_INT_ARGB);
        float[] hsv = new float[3];
        for (int y = 0; y < h; y++) {
            for (int x = 0; x < w; x++) {
                int argb = source.getRGB(x, y);
                int a = argb >>> 24, r = (argb >> 16) & 255, g = (argb >> 8) & 255, b = argb & 255;
                Color.RGBtoHSB(r, g, b, hsv);
                int rgb;
                if (horizon) {
                    // the cartoon's wormhole: pale blue-white
                    rgb = Color.HSBtoRGB(0.58F, hsv[1] * 0.30F, clamp(0.55F + hsv[2] * 0.5F));
                } else if (hsv[1] < 0.22F) {
                    // stone and metal: pale, the grooves darkening to ink
                    float lum = (0.299F * r + 0.587F * g + 0.114F * b) / 255F;
                    float t = (float) Math.pow(clamp((lum - 0.12F) / 0.42F), 0.85);
                    rgb = (mix(INK[0], PALE[0], t) << 16) | (mix(INK[1], PALE[1], t) << 8) | mix(INK[2], PALE[2], t);
                } else if (hsv[0] < 0.17F || hsv[0] > 0.94F) {
                    // orange and red: the chevrons' lime-yellow
                    rgb = Color.HSBtoRGB(LIME_HUE, clamp(hsv[1] * 1.05F), hsv[2]);
                } else if (hsv[0] > 0.45F && hsv[0] < 0.75F) {
                    rgb = Color.HSBtoRGB(hsv[0], hsv[1] * 0.35F, clamp(hsv[2] * 1.15F));
                } else {
                    rgb = argb;
                }
                out.setRGB(x, y, (a << 24) | (rgb & 0xFFFFFF));
            }
        }
        return out;
    }

    private static float clamp(float v) {
        return Math.max(0F, Math.min(1F, v));
    }

    private static int mix(int from, int to, float t) {
        return Math.round(from + (to - from) * t);
    }
}
