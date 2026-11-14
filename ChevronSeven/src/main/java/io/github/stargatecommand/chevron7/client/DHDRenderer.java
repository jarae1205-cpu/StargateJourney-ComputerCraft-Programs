package io.github.stargatecommand.chevron7.client;

import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.joml.Matrix3f;
import org.joml.Matrix4f;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;

import io.github.stargatecommand.chevron7.Chevron7;
import io.github.stargatecommand.chevron7.DHDBlock;
import io.github.stargatecommand.chevron7.DHDBlockEntity;
import io.github.stargatecommand.chevron7.GateAddress;
import io.github.stargatecommand.chevron7.GateLook;
import io.github.stargatecommand.chevron7.StargateBlockEntity;
import io.github.stargatecommand.chevron7.StargateBlockEntity.State;
import net.minecraft.client.renderer.LevelRenderer;
import net.minecraft.client.renderer.LightTexture;
import net.minecraft.client.renderer.MultiBufferSource;
import net.minecraft.client.renderer.RenderType;
import net.minecraft.client.renderer.blockentity.BlockEntityRenderer;
import net.minecraft.client.renderer.blockentity.BlockEntityRendererProvider;
import net.minecraft.client.renderer.texture.OverlayTexture;
import net.minecraft.core.Direction;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.util.Mth;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.block.state.BlockState;

/**
 * The DHD's round top, after the Carter Addon Pack's: a slanted orange collar on the pedestal, two
 * rings of glyph keys and a blue dome. The keys of the symbols the gate has locked light up in the
 * gate look's chevron colour, one by one as it dials, and the dome glows while the wormhole is open.
 * Local space: x to the right as you face the DHD, y up, z towards you; the block's centre is x = z = 0.
 */
public class DHDRenderer implements BlockEntityRenderer<DHDBlockEntity>
{
	static final ResourceLocation BODY = Chevron7.id("textures/entity/dhd_body.png");
	static final ResourceLocation KEY = Chevron7.id("textures/entity/dhd_button.png");
	static final int FULL_BRIGHT = LightTexture.FULL_BRIGHT;

	// the slanted top: a disc of radius TOP_R around (0, TOP_Y, 0), tipped towards the front
	static final float TILT = (float) Math.toRadians(28), TOP_Y = 0.9F, TOP_R = 0.66F;
	static final float SIN = Mth.sin(TILT), COS = Mth.cos(TILT);
	// where the pedestal's octagon ends
	static final float NECK_R = 0.36F, NECK_Y = 0.56F;
	static final int OUTER = 20, SEGMENTS = 40;
	static final float DOME_R = 0.2F;

	public DHDRenderer(BlockEntityRendererProvider.Context context) {}

	@Override
	public void render(DHDBlockEntity dhd, float partialTick, PoseStack pose, MultiBufferSource buffers, int packedLight, int packedOverlay)
	{
		Level level = dhd.getLevel();
		if(level == null)
			return;
		BlockState state = dhd.getBlockState();
		Direction facing = state.hasProperty(DHDBlock.FACING) ? state.getValue(DHDBlock.FACING) : Direction.NORTH;
		int light = LevelRenderer.getLightColor(level, dhd.getBlockPos().above());
		float time = level.getGameTime() + partialTick;

		StargateBlockEntity gate = dhd.gate();
		GateLook look = gate == null ? GateLook.SG1 : gate.getLook();
		Set<Integer> lit = new HashSet<>();
		boolean open = false, dialing = false;
		if(gate != null && gate.getState() != State.RESETTING && gate.getState() != State.CLOSING && gate.isOutgoing())
		{
			List<Integer> encoded = gate.getEncoded();
			lit.addAll(encoded);
			open = gate.getState().connected();
			dialing = !open && !encoded.isEmpty();
		}

		pose.pushPose();
		pose.translate(0.5, 0, 0.5);
		pose.mulPose(Axis.YP.rotationDegrees(-facing.toYRot()));
		Matrix4f m = pose.last().pose();
		Matrix3f n = pose.last().normal();

		collar(buffers.getBuffer(RenderType.entityCutoutNoCull(BODY)), m, n, light);
		keys(buffers.getBuffer(RenderType.entityCutoutNoCull(KEY)), m, n, look, lit, light);
		glyphs(buffers.getBuffer(RenderType.entityCutoutNoCull(StargateRenderer.GLYPHS)), m, n, look, lit, light);
		float glow = open ? 1.0F : dialing ? 0.55F + 0.25F * Mth.sin(time * 0.3F) : 0.3F;
		dome(buffers.getBuffer(RenderType.entityCutoutNoCull(KEY)), m, n, glow, open || dialing ? FULL_BRIGHT : light);

		pose.popPose();
	}

	//============================================================================================

	/** A point on the slanted top: r from the centre, at angle a (0 = away from you, clockwise), h above the surface. */
	private static float[] top(float r, float a, float h)
	{
		float x = r * Mth.sin(a), c = r * Mth.cos(a); // c: away from you
		// the far side is higher: tipped by TILT about the x axis
		float y = TOP_Y + c * SIN + h * COS;
		float z = -c * COS + h * SIN;
		return new float[] {x, y, z};
	}

	private static void vertex(VertexConsumer vc, Matrix4f m, Matrix3f n, float[] p, float u, float v,
			float r, float g, float b, int light, float nx, float ny, float nz)
	{
		vc.vertex(m, p[0], p[1], p[2]).color(r, g, b, 1).uv(u, v).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light)
				.normal(n, nx, ny, nz).endVertex();
	}

	private static void quad(VertexConsumer vc, Matrix4f m, Matrix3f n, float[] a, float[] b, float[] c, float[] d,
			float[] uv, float r, float g, float bl, int light, float nx, float ny, float nz)
	{
		vertex(vc, m, n, a, uv[0], uv[1], r, g, bl, light, nx, ny, nz);
		vertex(vc, m, n, b, uv[2], uv[3], r, g, bl, light, nx, ny, nz);
		vertex(vc, m, n, c, uv[4], uv[5], r, g, bl, light, nx, ny, nz);
		vertex(vc, m, n, d, uv[6], uv[7], r, g, bl, light, nx, ny, nz);
	}

	/** The orange collar from the pedestal up to the rim of the top, the dark face under the keys and the rim's edge. */
	private static void collar(VertexConsumer vc, Matrix4f m, Matrix3f n, int light)
	{
		float ny = COS, nz = SIN;
		for(int i = 0; i < SEGMENTS; i++)
		{
			float a0 = Mth.TWO_PI * i / SEGMENTS, a1 = Mth.TWO_PI * (i + 1) / SEGMENTS;
			float u0 = (i % 8) / 8.0F, u1 = u0 + 1 / 8.0F;
			float[] low0 = {NECK_R * Mth.sin(a0), NECK_Y, -NECK_R * Mth.cos(a0)};
			float[] low1 = {NECK_R * Mth.sin(a1), NECK_Y, -NECK_R * Mth.cos(a1)};
			float[] rim0 = top(TOP_R, a0, -0.06F), rim1 = top(TOP_R, a1, -0.06F);
			float[] edge0 = top(TOP_R, a0, 0.02F), edge1 = top(TOP_R, a1, 0.02F);
			float sx = Mth.sin((a0 + a1) / 2), sz = -Mth.cos((a0 + a1) / 2);
			// collar: outside and inside, so it shows from every side
			quad(vc, m, n, low0, low1, rim1, rim0, new float[] {u0, 1, u1, 1, u1, 0.1F, u0, 0.1F}, 1, 1, 1, light, sx, 0.4F, sz);
			quad(vc, m, n, rim0, rim1, low1, low0, new float[] {u0, 0.1F, u1, 0.1F, u1, 1, u0, 1}, 0.7F, 0.7F, 0.7F, light, -sx, -0.4F, -sz);
			// the rim's edge, in the trim colour
			quad(vc, m, n, rim0, rim1, edge1, edge0, new float[] {u0, 0.0F, u1, 0.0F, u1, 0.06F, u0, 0.06F}, 1, 0.95F, 0.85F, light, sx, 0, sz);
			// the dark face the keys sit on
			float[] in0 = top(DOME_R, a0, 0.02F), in1 = top(DOME_R, a1, 0.02F);
			quad(vc, m, n, in0, edge0, edge1, in1, new float[] {0.4F, 0.5F, 0.45F, 0.5F, 0.45F, 0.55F, 0.4F, 0.55F},
					0.16F, 0.11F, 0.08F, light, 0, ny, nz);
		}
	}

	/** Which ring and angle a symbol's key has: symbols 0-19 on the outer ring, 20-38 on the inner one. */
	private static float[] keySlot(int symbol)
	{
		boolean outer = symbol < OUTER;
		int count = outer ? OUTER : GateAddress.SYMBOLS - OUTER, index = outer ? symbol : symbol - OUTER;
		float span = Mth.TWO_PI / count, a = index * span;
		float r0 = outer ? 0.47F : 0.25F, r1 = outer ? 0.64F : 0.44F;
		return new float[] {r0, r1, a - span * 0.44F, a + span * 0.44F};
	}

	private static void keys(VertexConsumer vc, Matrix4f m, Matrix3f n, GateLook look, Set<Integer> lit, int light)
	{
		for(int s = 0; s < GateAddress.SYMBOLS; s++)
		{
			float[] k = keySlot(s);
			boolean on = lit.contains(s);
			float h = on ? 0.03F : 0.045F; // a lit key is pressed in
			float[] a = top(k[0], k[2], h), b = top(k[1], k[2], h), c = top(k[1], k[3], h), d = top(k[0], k[3], h);
			float[] uv = {0, 1, 0, 0, 1, 0, 1, 1};
			if(on)
				quad(vc, m, n, a, b, c, d, uv, look.chevronR, look.chevronG, look.chevronB, FULL_BRIGHT, 0, COS, SIN);
			else
				quad(vc, m, n, a, b, c, d, uv, 0.62F, 0.52F, 0.40F, light, 0, COS, SIN);
		}
	}

	private static void glyphs(VertexConsumer vc, Matrix4f m, Matrix3f n, GateLook look, Set<Integer> lit, int light)
	{
		for(int s = 0; s < GateAddress.SYMBOLS; s++)
		{
			float[] k = keySlot(s);
			boolean on = lit.contains(s);
			float rm = (k[0] + k[1]) / 2, am = (k[2] + k[3]) / 2, h = (on ? 0.03F : 0.045F) + 0.004F;
			float half = Math.min((k[1] - k[0]) * 0.42F, rm * (k[3] - k[2]) * 0.5F);
			// the glyph stands upright along the radius: its top points outwards
			float da = half / rm;
			float[] a = top(rm + half, am - da, h), b = top(rm + half, am + da, h), c = top(rm - half, am + da, h), d = top(rm - half, am - da, h);
			float u0 = (s % 8) / 8.0F, v0 = (s / 8) / 5.0F, u1 = u0 + 1 / 8.0F, v1 = v0 + 1 / 5.0F;
			float[] uv = {u0, v0, u1, v0, u1, v1, u0, v1};
			if(on)
				quad(vc, m, n, a, b, c, d, uv, 0.25F, 0.12F, 0.04F, FULL_BRIGHT, 0, COS, SIN);
			else
				quad(vc, m, n, a, b, c, d, uv, look.glyphR, look.glyphG, look.glyphB, light, 0, COS, SIN);
		}
	}

	/** The dome in the middle: blue, brighter while the gate dials and glowing while the wormhole is open. */
	private static void dome(VertexConsumer vc, Matrix4f m, Matrix3f n, float glow, int light)
	{
		float[][] rings = {{DOME_R, 0.02F}, {DOME_R * 0.8F, 0.08F}, {DOME_R * 0.45F, 0.115F}, {0.0F, 0.125F}};
		float r = 0.12F + 0.38F * glow, g = 0.42F + 0.5F * glow, b = 0.7F + 0.3F * glow;
		float[] uv = {0.3F, 0.3F, 0.7F, 0.3F, 0.7F, 0.7F, 0.3F, 0.7F};
		for(int ring = 0; ring < rings.length - 1; ring++)
		{
			float shade = 0.85F + 0.05F * ring;
			for(int i = 0; i < SEGMENTS / 2; i++)
			{
				float a0 = Mth.TWO_PI * i / (SEGMENTS / 2), a1 = Mth.TWO_PI * (i + 1) / (SEGMENTS / 2);
				float[] p0 = top(rings[ring][0], a0, rings[ring][1]), p1 = top(rings[ring][0], a1, rings[ring][1]);
				float[] q1 = top(rings[ring + 1][0], a1, rings[ring + 1][1]), q0 = top(rings[ring + 1][0], a0, rings[ring + 1][1]);
				quad(vc, m, n, p0, p1, q1, q0, uv, r * shade, g * shade, b * shade, light, 0, COS, SIN);
			}
		}
	}
}
