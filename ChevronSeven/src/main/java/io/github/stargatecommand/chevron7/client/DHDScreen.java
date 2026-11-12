package io.github.stargatecommand.chevron7.client;

import java.util.List;

import javax.annotation.Nullable;

import io.github.stargatecommand.chevron7.DHDBlock;
import io.github.stargatecommand.chevron7.GateAddress;
import io.github.stargatecommand.chevron7.GateShape;
import io.github.stargatecommand.chevron7.Net;
import io.github.stargatecommand.chevron7.StargateBlockEntity;
import io.github.stargatecommand.chevron7.StargateBlockEntity.State;
import net.minecraft.client.Minecraft;
import net.minecraft.client.gui.GuiGraphics;
import net.minecraft.client.gui.screens.Screen;
import net.minecraft.client.resources.sounds.SimpleSoundInstance;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.sounds.SoundEvents;
import net.minecraft.util.Mth;

/**
 * The Dial Home Device: two rings of symbol keys around the big dial button.
 * Outer ring: symbols 0 (point of origin) to 19; inner ring: 20 to 38.
 */
public class DHDScreen extends Screen
{
	/** The gate picked on each DHD, while the game runs. */
	private static final java.util.Map<BlockPos, BlockPos> CHOICES = new java.util.HashMap<>();
	private static final int PREV_GATE = -100, NEXT_GATE = -101;

	private final BlockPos dhd;
	private int cx, cy, outerRadius, innerRadius, keySize, buttonRadius;

	public DHDScreen(BlockPos dhd)
	{
		super(Component.translatable("screen.chevron7.dhd"));
		this.dhd = dhd;
	}

	@Override
	protected void init()
	{
		int size = Math.min(width - 20, height - 56);
		outerRadius = Math.max(60, size * 43 / 100);
		innerRadius = outerRadius * 64 / 100;
		keySize = Math.max(14, outerRadius * 22 / 100);
		buttonRadius = innerRadius * 44 / 100;
		cx = width / 2;
		cy = 24 + outerRadius + keySize / 2;
	}

	@Override
	public boolean isPauseScreen()
	{
		return false;
	}

	@Nullable
	private StargateBlockEntity gate()
	{
		Minecraft minecraft = Minecraft.getInstance();
		return minecraft.level == null ? null : GateShape.chosenGate(minecraft.level, dhd, DHDBlock.RANGE, CHOICES.get(dhd));
	}

	private List<StargateBlockEntity> gatesInRange()
	{
		Minecraft minecraft = Minecraft.getInstance();
		return minecraft.level == null ? List.of() : GateShape.gatesNear(minecraft.level, dhd, DHDBlock.RANGE);
	}

	/** Picks the next or previous gate in range. */
	private void cycleGate(int step)
	{
		List<StargateBlockEntity> gates = gatesInRange();
		if(gates.size() < 2)
			return;
		StargateBlockEntity current = gate();
		int index = current == null ? 0 : Math.max(0, gates.indexOf(current));
		int next = Math.floorMod(index + step, gates.size());
		CHOICES.put(dhd, gates.get(next).getBlockPos());
	}

	/** The arrows either side of the title, when several gates are in range: {left x, right x, y}. */
	private int[] gateArrows()
	{
		int text = font.width(title) + font.width("  ") + font.width(Component.translatable("screen.chevron7.gate_n", 7, 7));
		int half = text / 2 + 14;
		return new int[] {cx - half, cx + half - 10, 4};
	}

	/** Centre of a key: symbol 0 at the top of the outer ring, going clockwise. */
	private int[] keyCenter(int symbol)
	{
		boolean outer = symbol < 20;
		int index = outer ? symbol : symbol - 20;
		int count = outer ? 20 : 19;
		double a = Math.PI * 2 * index / count;
		int r = outer ? outerRadius : innerRadius;
		return new int[] {cx + (int) Math.round(Math.sin(a) * r), cy - (int) Math.round(Math.cos(a) * r)};
	}

	private int keyAt(double mx, double my)
	{
		for(int s = 0; s < GateAddress.SYMBOLS; s++)
		{
			int[] c = keyCenter(s);
			int half = (s < 20 ? keySize : keySize * 9 / 10) / 2;
			if(Math.abs(mx - c[0]) <= half && Math.abs(my - c[1]) <= half)
				return s;
		}
		if((mx - cx) * (mx - cx) + (my - cy) * (my - cy) <= buttonRadius * buttonRadius)
			return Net.DIAL_BUTTON;
		if(gatesInRange().size() > 1)
		{
			int[] a = gateArrows();
			if(my >= a[2] && my <= a[2] + 11)
			{
				if(mx >= a[0] && mx <= a[0] + 10)
					return PREV_GATE;
				if(mx >= a[1] && mx <= a[1] + 10)
					return NEXT_GATE;
			}
		}
		if(irisButton() != null)
		{
			int[] b = irisButton();
			if(mx >= b[0] && mx <= b[2] && my >= b[1] && my <= b[3])
				return Net.IRIS_BUTTON;
		}
		return Integer.MIN_VALUE;
	}

	@Nullable
	private int[] irisButton()
	{
		StargateBlockEntity gate = gate();
		if(gate == null || !gate.hasIris())
			return null;
		int w = 46, h = 16;
		int x = cx + outerRadius + keySize / 2 - w, y = cy + outerRadius + keySize / 2 + 4;
		return new int[] {x, y, x + w, y + h};
	}

	@Override
	public boolean mouseClicked(double mx, double my, int button)
	{
		if(button == 0)
		{
			int key = keyAt(mx, my);
			if(key == PREV_GATE || key == NEXT_GATE)
			{
				cycleGate(key == NEXT_GATE ? 1 : -1);
				Minecraft.getInstance().getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.UI_BUTTON_CLICK.value(), 1.0F, 0.3F));
				return true;
			}
			if(key != Integer.MIN_VALUE)
			{
				StargateBlockEntity chosen = gate();
				Net.CHANNEL.sendToServer(new Net.DhdPress(dhd, key, chosen == null ? null : chosen.getBlockPos()));
				Minecraft.getInstance().getSoundManager().play(SimpleSoundInstance.forUI(SoundEvents.STONE_BUTTON_CLICK_ON, 1.4F, 0.4F));
				return true;
			}
		}
		return super.mouseClicked(mx, my, button);
	}

	@Override
	public void render(GuiGraphics g, int mx, int my, float partialTick)
	{
		renderBackground(g);
		StargateBlockEntity gate = gate();
		float time = Minecraft.getInstance().level == null ? 0 : Minecraft.getInstance().level.getGameTime() + partialTick;

		// the console
		disc(g, cx, cy, outerRadius + keySize / 2 + 6, 0xFF3A2E26);
		disc(g, cx, cy, outerRadius + keySize / 2 + 3, 0xFF5B4A3C);
		disc(g, cx, cy, innerRadius + keySize / 2 + 2, 0xFF4A3C31);

		List<Integer> planned = gate == null ? List.of() : gate.plannedSymbols();
		List<Integer> locked = gate == null ? List.of() : gate.getEncoded();
		boolean incoming = gate != null && gate.getState().connected() && !gate.isOutgoing();
		int hover = keyAt(mx, my);
		for(int s = 0; s < GateAddress.SYMBOLS; s++)
		{
			int[] c = keyCenter(s);
			int size = s < 20 ? keySize : keySize * 9 / 10;
			int half = size / 2;
			boolean lit = !incoming && planned.contains(s);
			boolean done = !incoming && locked.contains(s);
			int face = done ? 0xFFE08A2A : lit ? 0xFFB86A24 : (hover == s ? 0xFF8C7A68 : 0xFF6E5E50);
			g.fill(c[0] - half, c[1] - half, c[0] + half, c[1] + half, 0xFF221A14);
			g.fill(c[0] - half + 1, c[1] - half + 1, c[0] + half - 1, c[1] + half - 1, face);
			int glyph = size - 4;
			if(lit || done)
				g.setColor(1.0F, 0.95F, 0.85F, 1.0F);
			else
				g.setColor(0.12F, 0.1F, 0.08F, 1.0F);
			g.blit(StargateRenderer.GLYPHS, c[0] - glyph / 2, c[1] - glyph / 2, glyph, glyph, (s % 8) * 32, (s / 8) * 32, 32, 32, 256, 160);
			g.setColor(1, 1, 1, 1);
		}

		// the big button: lit while a wormhole is open or a dial is going
		boolean active = gate != null && (gate.getState().connected() || !planned.isEmpty());
		float pulse = active ? 0.85F + 0.15F * Mth.sin(time * 0.3F) : 0;
		disc(g, cx, cy, buttonRadius + 2, 0xFF1C0D0A);
		disc(g, cx, cy, buttonRadius, active ? rgb(0.95F * pulse, 0.22F * pulse, 0.12F * pulse) : (hover == Net.DIAL_BUTTON ? 0xFF8E2A1C : 0xFF6A1E15));
		disc(g, cx - buttonRadius / 4, cy - buttonRadius / 4, buttonRadius / 3, active ? 0x55FFFFFF : 0x22FFFFFF);

		// text, and the gate picker when several gates are in range
		List<StargateBlockEntity> inRange = gatesInRange();
		if(inRange.size() > 1 && gate != null)
		{
			Component which = Component.translatable("screen.chevron7.gate_n", inRange.indexOf(gate) + 1, inRange.size());
			g.drawCenteredString(font, Component.empty().append(title).append("  ").append(which), cx, 6, 0xFFE8D9C0);
			int[] a = gateArrows();
			for(int i = 0; i < 2; i++)
			{
				int ax = i == 0 ? a[0] : a[1];
				boolean over = hover == (i == 0 ? PREV_GATE : NEXT_GATE);
				g.fill(ax, a[2], ax + 10, a[2] + 11, over ? 0xFF8C7A68 : 0xFF5B4A3C);
				g.drawCenteredString(font, i == 0 ? "<" : ">", ax + 5, a[2] + 2, 0xFFFFFFFF);
			}
		}
		else
			g.drawCenteredString(font, title, cx, 6, 0xFFE8D9C0);
		String status;
		if(gate == null)
			status = Component.translatable("screen.chevron7.no_gate").getString();
		else
		{
			status = Component.translatable("screen.chevron7.this_gate", GateAddress.format(gate.getAddress())).getString() + "   "
					+ Component.translatable("screen.chevron7.state." + stateKey(gate)).getString();
		}
		g.drawCenteredString(font, status, cx, height - 28, 0xFFE8D9C0);
		if(gate != null && !planned.isEmpty() && !gate.getState().connected())
			g.drawCenteredString(font, Component.translatable("screen.chevron7.dialing", format(planned)), cx, height - 16, 0xFFFFB060);

		int[] iris = irisButton();
		if(iris != null && gate != null)
		{
			g.fill(iris[0], iris[1], iris[2], iris[3], 0xFF222428);
			g.fill(iris[0] + 1, iris[1] + 1, iris[2] - 1, iris[3] - 1, hover == Net.IRIS_BUTTON ? 0xFF5C6470 : 0xFF444A54);
			String label = Component.translatable(gate.isIrisClosing() ? "screen.chevron7.iris_closed" : "screen.chevron7.iris_open").getString();
			g.drawCenteredString(font, label, (iris[0] + iris[2]) / 2, iris[1] + 4, 0xFFFFFFFF);
		}

		if(hover >= 0)
		{
			Component tip = hover == GateAddress.POINT_OF_ORIGIN ? Component.translatable("screen.chevron7.point_of_origin")
					: Component.translatable("screen.chevron7.symbol", hover);
			g.renderTooltip(font, tip, mx, my);
		}
		super.render(g, mx, my, partialTick);
	}

	private static String stateKey(StargateBlockEntity gate)
	{
		State state = gate.getState();
		if(state.connected())
			return gate.isOutgoing() ? "outgoing" : "incoming";
		return state.name().toLowerCase();
	}

	private static String format(List<Integer> symbols)
	{
		StringBuilder builder = new StringBuilder("-");
		for(int s : symbols)
			builder.append(s).append('-');
		return builder.toString();
	}

	private static int rgb(float r, float g, float b)
	{
		return 0xFF000000 | ((int) (Mth.clamp(r, 0, 1) * 255) << 16) | ((int) (Mth.clamp(g, 0, 1) * 255) << 8) | (int) (Mth.clamp(b, 0, 1) * 255);
	}

	private static void disc(GuiGraphics g, int x, int y, int r, int color)
	{
		for(int dy = -r; dy <= r; dy++)
		{
			int dx = (int) Math.sqrt((double) r * r - (double) dy * dy);
			g.fill(x - dx, y + dy, x + dx + 1, y + dy + 1, color);
		}
	}
}
