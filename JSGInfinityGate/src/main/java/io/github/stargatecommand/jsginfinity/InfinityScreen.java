package io.github.stargatecommand.jsginfinity;

import dev.tauri.jsg.api.raycaster.util.RayCastedButton;
import dev.tauri.jsg.api.stargate.network.address.symbol.SymbolTypeRegistry;
import dev.tauri.jsg.api.stargate.network.address.symbol.types.SymbolMilkyWayEnum;
import dev.tauri.jsg.api.util.vectors.Vector3f;
import dev.tauri.jsg.raycaster.instances.RaycasterDHD;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.List;

/**
 * The Infinity DHD's console: a pedestal with a tilted screen on top, its keys laid out on the
 * screen. The keys you see and the places JSG looks for a pressed key are both made from this
 * layout, so they line up exactly.
 * <p>
 * Positions are in the frame JSG's DHD raycaster uses: x to the left of someone standing in front
 * of the DHD, y towards them, z up, in blocks from the middle of the block's floor. JSG turns
 * and moves them with the DHD's rotation, the same way for drawing and for pressing.
 * <p>
 * On the screen itself, u runs to the right and w up the slope, away from the player, from the
 * front edge of the glass.
 */
public final class InfinityScreen {
    private InfinityScreen() {}

    /** The console's head: its footprint, the bottom of it, and the height of its sloping top. */
    public static final float HEAD_X = 0.58f, HEAD_BACK = -0.40f, HEAD_FRONT = 0.40f, HEAD_BOTTOM = 0.72f;
    /** The glass: its half-width, its front and back edges, and how far it sits below the bezel. */
    public static final float GLASS_X = 0.53f, GLASS_FRONT = 0.35f, GLASS_BACK = -0.35f, GLASS_DROP = 0.012f;
    private static final float TOP_AT_CENTRE = 1.03f, SLOPE = 0.55f;
    /** The length of the glass up its slope. */
    public static final float GLASS_LENGTH = (float) ((GLASS_FRONT - GLASS_BACK) * Math.sqrt(1 + SLOPE * SLOPE));

    /** A key's size on the glass, and the pitch of the two pads of keys either side of the dial button. */
    public static final float KEY_U = 0.083f, KEY_W = 0.11f;
    private static final float PITCH_U = 0.095f, PITCH_W = 0.13f, PAD_INNER = 0.20f, FIRST_ROW = 0.615f;
    /** The dial button in the middle, round, and the strip at the top of the glass that shows what's dialled. */
    public static final float BRB_W = 0.40f, BRB_R = 0.10f;
    public static final float STRIP_W = 0.745f, STRIP_PITCH = 0.10f, STRIP_SIZE = 0.085f;
    /** The control-crystal lamp, low in the middle. */
    public static final float LAMP_W = 0.12f, LAMP_R = 0.03f;

    /** How high the head's top is at y. */
    public static float top(float y) {
        return TOP_AT_CENTRE - SLOPE * y;
    }

    /** A point on the glass, lifted a little above it. */
    public static Vector3f onGlass(float u, float w, float lift) {
        float y = GLASS_FRONT - w * (GLASS_FRONT - GLASS_BACK) / GLASS_LENGTH;
        return new Vector3f(-u, y, top(y) - GLASS_DROP + lift); // the frame's x runs to the player's left
    }

    /** One symbol key: the symbol and the middle of its key on the glass. */
    public record Key(SymbolMilkyWayEnum symbol, float u, float w) {
        /** The key's corners, a little above the glass: top left, top right, bottom right, bottom left as the player sees it. */
        public List<Vector3f> corners(float lift) {
            float u0 = u - KEY_U / 2, u1 = u + KEY_U / 2, w0 = w - KEY_W / 2, w1 = w + KEY_W / 2;
            return List.of(onGlass(u0, w1, lift), onGlass(u1, w1, lift), onGlass(u1, w0, lift), onGlass(u0, w0, lift));
        }

        /**
         * The key's outline as JSG's raycaster wants it. JSG cuts an outline into triangles that
         * all share its first point, and a press exactly on the line between two of them can miss
         * both; starting the outline at the key's middle keeps its middle pressable.
         */
        public List<Vector3f> pressable(float lift) {
            List<Vector3f> c = corners(lift);
            return List.of(onGlass(u, w, lift), c.get(0), c.get(1), c.get(2), c.get(3), c.get(0));
        }
    }

    private static List<Key> keys;

    /**
     * The 38 symbol keys in order of their ids: the first 19 on the left pad and the rest on the
     * right, four to a row from the top, the short bottom rows towards the dial button.
     */
    public static List<Key> keys() {
        if (keys == null) {
            List<SymbolMilkyWayEnum> symbols = new ArrayList<>(Arrays.stream(SymbolMilkyWayEnum.values())
                    .filter(s -> !s.brb()).sorted(Comparator.comparingInt(SymbolMilkyWayEnum::getId)).toList());
            List<Key> list = new ArrayList<>();
            int half = (symbols.size() + 1) / 2;
            for (int i = 0; i < symbols.size(); i++) {
                boolean left = i < half;
                int n = left ? i : i - half, padSize = left ? half : symbols.size() - half;
                int row = n / 4, col = n % 4, lastRow = (padSize - 1) / 4;
                float u;
                if (left) {
                    // the left pad's short last row moves over to sit by the dial button, as the right pad's does
                    if (row == lastRow) col += 4 - (padSize - lastRow * 4);
                    u = -(PAD_INNER + (3 - col) * PITCH_U);
                } else {
                    u = PAD_INNER + col * PITCH_U;
                }
                list.add(new Key(symbols.get(i), u, FIRST_ROW - row * PITCH_W));
            }
            keys = List.copyOf(list);
        }
        return keys;
    }

    /** The dial button's outline, round, as a many-sided polygon a little above the glass, starting from its middle as {@link Key#pressable} does. */
    public static List<Vector3f> brbOutline(float lift, int sides) {
        List<Vector3f> points = new ArrayList<>();
        points.add(onGlass(0, BRB_W, lift));
        for (int i = 0; i <= sides; i++) {
            double a = 2 * Math.PI * i / sides;
            points.add(onGlass((float) (BRB_R * Math.sin(a)), (float) (BRB_W + BRB_R * Math.cos(a)), lift));
        }
        return points;
    }

    /** JSG's DHD presses, with the keys where this screen shows them. */
    public static final class Raycaster extends RaycasterDHD {
        public static final Raycaster INSTANCE = new Raycaster();
        /** The height of the pressable keys above the glass: where they're drawn. */
        public static final float LIFT = 0.002f;
        private List<RayCastedButton> buttons;

        private Raycaster() {}

        @Override
        protected List<RayCastedButton> getButtons() {
            if (buttons == null) {
                List<RayCastedButton> list = new ArrayList<>();
                for (Key key : keys()) {
                    list.add(new RayCastedButton(key.symbol().getId(), SymbolTypeRegistry.MILKYWAY, key.pressable(LIFT)));
                }
                SymbolMilkyWayEnum brb = Arrays.stream(SymbolMilkyWayEnum.values()).filter(SymbolMilkyWayEnum::brb).findFirst().orElseThrow();
                list.add(new RayCastedButton(brb.getId(), SymbolTypeRegistry.MILKYWAY, brbOutline(LIFT, 24)));
                buttons = List.copyOf(list);
            }
            return buttons;
        }
    }
}
