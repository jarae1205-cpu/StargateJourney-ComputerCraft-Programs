package io.github.stargatecommand.chevron7.client;

import org.joml.Matrix3f;
import org.joml.Matrix4f;

import com.mojang.blaze3d.vertex.PoseStack;
import com.mojang.blaze3d.vertex.VertexConsumer;
import com.mojang.math.Axis;

import io.github.stargatecommand.chevron7.Chevron7;
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

/**
 * Draws the whole gate: stone ring, turning symbol track, chevrons, event horizon, kawoosh and iris.
 * Local space: x to the right as you face the gate, y up, z out of the front; the ring's centre is the origin.
 */
public class StargateRenderer implements BlockEntityRenderer<StargateBlockEntity>
{
	// the ring, track and horizon textures come from the gate's look (GateLook)
	static final ResourceLocation CHEVRON = Chevron7.id("textures/entity/chevron.png");
	static final ResourceLocation IRIS = Chevron7.id("textures/entity/iris.png");
	public static final ResourceLocation GLYPHS = Chevron7.id("textures/gui/glyphs.png");

	static final float R_OUT = 3.42F, R_MID = 2.94F, R_IN = 2.45F;
	static final float D_OUT = 0.42F, D_TRACK = 0.33F;
	static final int FULL_BRIGHT = LightTexture.FULL_BRIGHT;

	public StargateRenderer(BlockEntityRendererProvider.Context context) {}

	@Override
	public boolean shouldRenderOffScreen(StargateBlockEntity gate)
	{
		return true;
	}

	@Override
	public int getViewDistance()
	{
		return 128;
	}

	@Override
	public void render(StargateBlockEntity gate, float partialTick, PoseStack pose, MultiBufferSource buffers, int packedLight, int packedOverlay)
	{
		Level level = gate.getLevel();
		if(level == null)
			return;
		float time = level.getGameTime() + partialTick;
		Direction facing = gate.getFacing();
		int light = LevelRenderer.getLightColor(level, gate.getBlockPos().above(3).relative(facing));

		pose.pushPose();
		pose.translate(0.5, gate.centerHeight(), 0.5);
		pose.mulPose(Axis.YP.rotationDegrees(-facing.toYRot()));
		boolean supergate = gate.isSupergate();
		if(supergate)
			pose.scale(gate.scale(), gate.scale(), gate.scale());

		float angle = gate.ringAngle(time);
		Matrix4f m = pose.last().pose();
		Matrix3f n = pose.last().normal();

		GateLook look = gate.getLook();
		if(supergate)
		{
			supergate(gate, look, time, buffers, m, n, light);
		}
		else
		{
			ring(buffers.getBuffer(RenderType.entityCutoutNoCull(look.stoneTexture())), m, n, R_MID, R_OUT, D_OUT, 36, 0, light, 1.0F);
			ring(buffers.getBuffer(RenderType.entityCutoutNoCull(look.trackTexture())), m, n, R_IN, R_MID, D_TRACK, GateAddress.SYMBOLS, angle, light, 1.0F);
			glyphs(buffers.getBuffer(RenderType.entityCutoutNoCull(GLYPHS)), m, n, angle, look, light);
			chevrons(gate, look, time, buffers, m, n, light);
		}
		horizon(gate, look, time, buffers.getBuffer(RenderType.entityTranslucent(look.horizonTexture())), m, n);
		if(!supergate)
			iris(gate, look, time, buffers.getBuffer(RenderType.entityCutoutNoCull(IRIS)), m, n, light);

		pose.popPose();
	}

	//============================================================================================

	private static void vertex(VertexConsumer vc, Matrix4f m, Matrix3f n, float x, float y, float z, float u, float v,
			float r, float g, float b, float a, int light, float nx, float ny, float nz)
	{
		vc.vertex(m, x, y, z).color(r, g, b, a).uv(u, v).overlayCoords(OverlayTexture.NO_OVERLAY).uv2(light).normal(n, nx, ny, nz).endVertex();
	}

	private static void quad(VertexConsumer vc, Matrix4f m, Matrix3f n, float[] p, float[] uv, float r, float g, float b, float a,
			int light, float nx, float ny, float nz)
	{
		for(int i = 0; i < 4; i++)
			vertex(vc, m, n, p[i * 3], p[i * 3 + 1], p[i * 3 + 2], uv[i * 2], uv[i * 2 + 1], r, g, b, a, light, nx, ny, nz);
	}

	/** A flat ring from r1 to r2, d thick on each side, in segments; rot turns it clockwise. */
	private static void ring(VertexConsumer vc, Matrix4f m, Matrix3f n, float r1, float r2, float d, int segments, float rot,
			int light, float shade)
	{
		for(int i = 0; i < segments; i++)
		{
			float a0 = (float) Math.toRadians(i * 360.0 / segments + rot);
			float a1 = (float) Math.toRadians((i + 1) * 360.0 / segments + rot);
			float s0 = Mth.sin(a0), c0 = Mth.cos(a0), s1 = Mth.sin(a1), c1 = Mth.cos(a1);
			float sm = Mth.sin((a0 + a1) / 2), cm = Mth.cos((a0 + a1) / 2);
			float[] uvFace = {0, 1, 0, 0, 1, 0, 1, 1};
			// front and back
			quad(vc, m, n, new float[] {r1 * s0, r1 * c0, d, r2 * s0, r2 * c0, d, r2 * s1, r2 * c1, d, r1 * s1, r1 * c1, d},
					uvFace, shade, shade, shade, 1, light, 0, 0, 1);
			quad(vc, m, n, new float[] {r1 * s1, r1 * c1, -d, r2 * s1, r2 * c1, -d, r2 * s0, r2 * c0, -d, r1 * s0, r1 * c0, -d},
					uvFace, shade, shade, shade, 1, light, 0, 0, -1);
			// rims
			float[] uvRim = {0, 0.85F, 0, 1, 1, 1, 1, 0.85F};
			float rim = shade * 0.8F;
			quad(vc, m, n, new float[] {r2 * s0, r2 * c0, d, r2 * s0, r2 * c0, -d, r2 * s1, r2 * c1, -d, r2 * s1, r2 * c1, d},
					uvRim, rim, rim, rim, 1, light, sm, cm, 0);
			quad(vc, m, n, new float[] {r1 * s1, r1 * c1, d, r1 * s1, r1 * c1, -d, r1 * s0, r1 * c0, -d, r1 * s0, r1 * c0, d},
					uvRim, rim * 0.8F, rim * 0.8F, rim * 0.8F, 1, light, -sm, -cm, 0);
		}
	}

	private static void glyphs(VertexConsumer vc, Matrix4f m, Matrix3f n, float rot, GateLook look, int light)
	{
		float rc = (R_IN + R_MID) / 2, h = 0.2F;
		for(int k = 0; k < GateAddress.SYMBOLS; k++)
		{
			float a = (float) Math.toRadians(k * StargateBlockEntity.STEP + rot);
			float nx = Mth.sin(a), ny = Mth.cos(a); // outwards
			float tx = ny, ty = -nx; // clockwise
			float cx = rc * nx, cy = rc * ny;
			float u0 = (k % 8) / 8.0F, v0 = (k / 8) / 5.0F, u1 = u0 + 1 / 8.0F, v1 = v0 + 1 / 5.0F;
			for(int side = 1; side >= -1; side -= 2)
			{
				float z = side * (D_TRACK + 0.003F);
				float sx = tx * side, sy = ty * side; // mirrored on the back so the symbols read the right way round
				float[] p = {
						cx - h * sx + h * nx, cy - h * sy + h * ny, z,
						cx + h * sx + h * nx, cy + h * sy + h * ny, z,
						cx + h * sx - h * nx, cy + h * sy - h * ny, z,
						cx - h * sx - h * nx, cy - h * sy - h * ny, z};
				quad(vc, m, n, p, new float[] {u0, v0, u1, v0, u1, v1, u0, v1}, look.glyphR, look.glyphG, look.glyphB, 1, light, 0, 0, side);
			}
		}
	}

	static final int SUPER_SEGMENTS = 40;

	/**
	 * An Ori supergate: a ring of separate dark segments with gaps between them and no symbols or
	 * chevrons. Their seams light one after another, clockwise from the top, as the chevrons lock,
	 * and all of them pulse while the wormhole is open.
	 */
	private static void supergate(StargateBlockEntity gate, GateLook look, float time, MultiBufferSource buffers, Matrix4f m, Matrix3f n, int light)
	{
		VertexConsumer stone = buffers.getBuffer(RenderType.entityCutoutNoCull(GateLook.ORI.stoneTexture()));
		State state = gate.getState();
		int lit;
		if(state.connected())
			lit = SUPER_SEGMENTS;
		else if(state == State.RESETTING || state == State.CLOSING)
			lit = 0;
		else
			lit = Math.min(SUPER_SEGMENTS, Math.round(SUPER_SEGMENTS * gate.getChevronsEngaged() / 7.0F));
		float pulse = state.connected() ? 0.75F + 0.25F * Mth.sin(time * 0.15F) : 1;
		float r1 = R_IN, r2 = R_OUT - 0.2F, d = D_OUT * 0.8F;
		float span = 360.0F / SUPER_SEGMENTS, gap = 1.3F;
		for(int k = 0; k < SUPER_SEGMENTS; k++)
		{
			float a0 = (float) Math.toRadians(k * span + gap), a1 = (float) Math.toRadians((k + 1) * span - gap);
			segment(stone, m, n, r1, r2, d, a0, a1, light);
		}
		VertexConsumer glow = buffers.getBuffer(RenderType.entityCutoutNoCull(CHEVRON));
		for(int k = 0; k < lit; k++)
		{
			float a0 = (float) Math.toRadians(k * span + gap * 1.6F), a1 = (float) Math.toRadians((k + 1) * span - gap * 1.6F);
			float s0 = Mth.sin(a0), c0 = Mth.cos(a0), s1 = Mth.sin(a1), c1 = Mth.cos(a1);
			float q1 = r1 + 0.05F, q2 = r1 + 0.32F;
			float[] uv = {0.3F, 0.3F, 0.7F, 0.3F, 0.7F, 0.7F, 0.3F, 0.7F};
			float r = look.chevronR * pulse, g = look.chevronG * pulse, b = look.chevronB * pulse;
			for(int side = 1; side >= -1; side -= 2)
			{
				float z = side * (d + 0.004F);
				float[] p = side > 0
						? new float[] {q1 * s0, q1 * c0, z, q2 * s0, q2 * c0, z, q2 * s1, q2 * c1, z, q1 * s1, q1 * c1, z}
						: new float[] {q1 * s1, q1 * c1, z, q2 * s1, q2 * c1, z, q2 * s0, q2 * c0, z, q1 * s0, q1 * c0, z};
				quad(glow, m, n, p, uv, r, g, b, 1, FULL_BRIGHT, 0, 0, side);
			}
		}
	}

	/** One supergate segment: a short block of the ring from angle a0 to a1, r1 to r2, d thick each side. */
	private static void segment(VertexConsumer vc, Matrix4f m, Matrix3f n, float r1, float r2, float d, float a0, float a1, int light)
	{
		float s0 = Mth.sin(a0), c0 = Mth.cos(a0), s1 = Mth.sin(a1), c1 = Mth.cos(a1);
		float sm = Mth.sin((a0 + a1) / 2), cm = Mth.cos((a0 + a1) / 2);
		float[] uv = {0, 1, 0, 0, 1, 0, 1, 1};
		float shade = 0.85F, rim = 0.65F;
		quad(vc, m, n, new float[] {r1 * s0, r1 * c0, d, r2 * s0, r2 * c0, d, r2 * s1, r2 * c1, d, r1 * s1, r1 * c1, d}, uv, shade, shade, shade, 1, light, 0, 0, 1);
		quad(vc, m, n, new float[] {r1 * s1, r1 * c1, -d, r2 * s1, r2 * c1, -d, r2 * s0, r2 * c0, -d, r1 * s0, r1 * c0, -d}, uv, shade, shade, shade, 1, light, 0, 0, -1);
		quad(vc, m, n, new float[] {r2 * s0, r2 * c0, d, r2 * s0, r2 * c0, -d, r2 * s1, r2 * c1, -d, r2 * s1, r2 * c1, d}, uv, rim, rim, rim, 1, light, sm, cm, 0);
		quad(vc, m, n, new float[] {r1 * s1, r1 * c1, d, r1 * s1, r1 * c1, -d, r1 * s0, r1 * c0, -d, r1 * s0, r1 * c0, d}, uv, rim, rim, rim, 1, light, -sm, -cm, 0);
		// the ends, facing the gaps
		quad(vc, m, n, new float[] {r1 * s0, r1 * c0, -d, r2 * s0, r2 * c0, -d, r2 * s0, r2 * c0, d, r1 * s0, r1 * c0, d}, uv, rim, rim, rim, 1, light, -c0, s0, 0);
		quad(vc, m, n, new float[] {r1 * s1, r1 * c1, d, r2 * s1, r2 * c1, d, r2 * s1, r2 * c1, -d, r1 * s1, r1 * c1, -d}, uv, rim, rim, rim, 1, light, c1, -s1, 0);
	}

	/** Which chevron slots are lit, and how far the top chevron has moved while locking. */
	private static void chevrons(StargateBlockEntity gate, GateLook look, float time, MultiBufferSource buffers, Matrix4f m, Matrix3f n, int light)
	{
		State state = gate.getState();
		int count = gate.getChevronsEngaged();
		boolean[] lit = new boolean[9];
		if(state != State.RESETTING)
			for(int i = 0; i < Math.min(count, StargateBlockEntity.CHEVRON_ORDER.length); i++)
				lit[StargateBlockEntity.CHEVRON_ORDER[i]] = true;
		float lock = gate.lockProgress(time);
		float topOffset = 0;
		if(lock >= 0)
		{
			lit[0] = true;
			topOffset = -0.12F * Mth.sin((float) Math.PI * lock);
		}
		if(state == State.CLOSING)
		{
			// fade out
			float p = Math.min(1, (time - gate.getStateTick()) / StargateBlockEntity.CLOSE_TICKS);
			if(p > 0.5F)
				lit = new boolean[9];
		}
		VertexConsumer housing = buffers.getBuffer(RenderType.entityCutoutNoCull(look.stoneTexture()));
		for(int slot = 0; slot < 9; slot++)
			chevronHousing(housing, m, n, slot * 40.0F, look.housing, light);
		VertexConsumer glow = buffers.getBuffer(RenderType.entityCutoutNoCull(CHEVRON));
		for(int slot = 0; slot < 9; slot++)
			chevronLight(glow, m, n, slot * 40.0F, lit[slot], slot == 0 ? topOffset : 0, look, light);
	}

	private static float[] at(float angleDeg, float u, float v, float z)
	{
		// u along the ring (clockwise), v outwards from the ring's middle radius
		float a = (float) Math.toRadians(angleDeg);
		float nx = Mth.sin(a), ny = Mth.cos(a), tx = ny, ty = -nx;
		float r = 3.18F + v;
		return new float[] {r * nx + u * tx, r * ny + u * ty, z};
	}

	private static float[] join(float[]... points)
	{
		float[] all = new float[points.length * 3];
		for(int i = 0; i < points.length; i++)
			System.arraycopy(points[i], 0, all, i * 3, 3);
		return all;
	}

	private static void chevronHousing(VertexConsumer vc, Matrix4f m, Matrix3f n, float angle, float shade, int light)
	{
		float outerHalf = 0.36F, innerHalf = 0.15F, top = 0.36F, bottom = -0.34F;
		float[] uv = {0, 0, 1, 0, 1, 1, 0, 1};
		for(int side = 1; side >= -1; side -= 2)
		{
			float zIn = side * D_OUT, zOut = side * (D_OUT + 0.12F);
			float[] ol = at(angle, -outerHalf, top, zOut), or = at(angle, outerHalf, top, zOut);
			float[] ir = at(angle, innerHalf, bottom, zOut), il = at(angle, -innerHalf, bottom, zOut);
			quad(vc, m, n, join(ol, or, ir, il), uv, shade, shade, shade, 1, light, 0, 0, side);
			// the sides of the housing
			float[] olB = at(angle, -outerHalf, top, zIn), orB = at(angle, outerHalf, top, zIn);
			float[] irB = at(angle, innerHalf, bottom, zIn), ilB = at(angle, -innerHalf, bottom, zIn);
			float s2 = shade * 0.7F;
			quad(vc, m, n, join(ol, olB, orB, or), uv, s2, s2, s2, 1, light, 0, 1, 0);
			quad(vc, m, n, join(or, orB, irB, ir), uv, s2, s2, s2, 1, light, 1, 0, 0);
			quad(vc, m, n, join(ir, irB, ilB, il), uv, s2, s2, s2, 1, light, 0, -1, 0);
			quad(vc, m, n, join(il, ilB, olB, ol), uv, s2, s2, s2, 1, light, -1, 0, 0);
		}
	}

	private static void chevronLight(VertexConsumer vc, Matrix4f m, Matrix3f n, float angle, boolean lit, float offset, GateLook look, int light)
	{
		float half = 0.33F, top = 0.34F + offset, bottom = -0.32F + offset;
		float[] uv = {0, 0, 1, 0, 1, 1, 0, 1};
		// unlit chevrons are a dull version of the lit colour
		float r = lit ? look.chevronR : 0.1F + 0.32F * look.chevronR;
		float g = lit ? look.chevronG : 0.1F + 0.32F * look.chevronG;
		float b = lit ? look.chevronB : 0.1F + 0.32F * look.chevronB;
		int l = lit ? FULL_BRIGHT : light;
		for(int side = 1; side >= -1; side -= 2)
		{
			float z = side * (D_OUT + 0.125F);
			quad(vc, m, n, join(at(angle, -half * side, top, z), at(angle, half * side, top, z), at(angle, half * side, bottom, z),
					at(angle, -half * side, bottom, z)), uv, r, g, b, 1, l, 0, 0, side);
		}
	}

	//============================================================================================

	private static void horizon(StargateBlockEntity gate, GateLook look, float time, VertexConsumer vc, Matrix4f m, Matrix3f n)
	{
		State state = gate.getState();
		if(!state.connected() && state != State.CLOSING)
			return;
		float since = time - gate.getStateTick();
		float radiusScale = 1, alpha = 0.93F, bulge = 0, flash = 0;
		if(state == State.OPENING)
		{
			float p = since / StargateBlockEntity.KAWOOSH_TICKS;
			if(p < 0.12F)
			{
				radiusScale = 0.2F + 0.8F * (p / 0.12F);
				flash = 1 - p / 0.12F;
			}
			else if(p < 0.62F && gate.irisProgress(time) < 0.5F)
			{
				float q = (p - 0.12F) / 0.5F;
				bulge = 4.3F * (float) Math.pow(Mth.sin((float) Math.PI * q), 0.8);
			}
		}
		else if(state == State.CLOSING)
		{
			float p = Math.min(1, since / StargateBlockEntity.CLOSE_TICKS);
			radiusScale = 1 - p * p;
			alpha *= 1 - p * 0.5F;
			if(radiusScale <= 0.01F)
				return;
		}

		final int rings = 12, segments = 48;
		float R = R_IN * radiusScale;
		float[][] x = new float[rings + 1][segments + 1], y = new float[rings + 1][segments + 1], z = new float[rings + 1][segments + 1];
		float[][] u = new float[rings + 1][segments + 1], v = new float[rings + 1][segments + 1], bright = new float[rings + 1][segments + 1];
		for(int i = 0; i <= rings; i++)
		{
			float rr = (float) i / rings;
			for(int j = 0; j <= segments; j++)
			{
				float a = (float) (j * Math.PI * 2 / segments);
				float r = rr * R;
				float ripple = 0.035F * Mth.sin(rr * 9 - time * 0.22F) * (1 - rr);
				float jet = bulge * (0.62F * (float) Math.exp(-(rr / 0.42F) * (rr / 0.42F)) + 0.38F * (1 - rr * rr));
				x[i][j] = r * Mth.sin(a);
				y[i][j] = r * Mth.cos(a);
				z[i][j] = ripple + jet + 0.02F;
				// swirl the texture: the middle turns faster than the edge
				float swirl = a + (1 - rr) * 0.9F * Mth.sin(time * 0.03F) + time * 0.006F;
				u[i][j] = 0.5F + 0.48F * rr * Mth.sin(swirl);
				v[i][j] = 0.5F + 0.48F * rr * Mth.cos(swirl);
				bright[i][j] = 0.78F + 0.22F * (1 - rr) + 0.5F * flash + (bulge > 0 ? 0.25F : 0);
			}
		}
		for(int i = 0; i < rings; i++)
		{
			for(int j = 0; j < segments; j++)
			{
				int[][] corners = {{i, j}, {i + 1, j}, {i + 1, j + 1}, {i, j + 1}};
				for(int[] c : corners)
				{
					float b = Math.min(1.0F, bright[c[0]][c[1]]);
					vertex(vc, m, n, x[c[0]][c[1]], y[c[0]][c[1]], z[c[0]][c[1]], u[c[0]][c[1]], v[c[0]][c[1]],
							look.horizonR * b, look.horizonG * b, look.horizonB * b, alpha, FULL_BRIGHT, 0, 0, 1);
				}
			}
		}
	}

	/**
	 * The iris: curved blades that overlap like a camera shutter. Each blade's edge sweeps from
	 * the rim towards the middle; closing turns the blades and shrinks the opening to nothing.
	 */
	private static void iris(StargateBlockEntity gate, GateLook look, float time, VertexConsumer vc, Matrix4f m, Matrix3f n, int light)
	{
		if(!gate.hasIris())
			return;
		float p = gate.irisProgress(time);
		if(p <= 0.001F)
			return;
		final int blades = 16, steps = 12;
		float outer = R_IN + 0.08F;
		float hole = R_IN * (1 - p);
		float turn = (float) Math.toRadians(70) * p;
		float curl = (float) Math.toRadians(100);
		float span = (float) (Math.PI * 2 / blades);
		float[] uv = {0, 0, 0, 1, 1, 1, 1, 0};
		for(int i = 0; i < blades; i++)
		{
			float shade = i % 2 == 0 ? 1.0F : 0.9F;
			float r = look.irisR * shade, g = look.irisG * shade, b = look.irisB * shade;
			for(int k = 0; k < steps; k++)
			{
				float r0 = hole + (outer - hole) * k / steps, r1 = hole + (outer - hole) * (k + 1) / steps;
				float a0 = i * span + turn + curl * (1 - r0 / outer), a1 = i * span + turn + curl * (1 - r1 / outer);
				float z = 0.06F;
				quad(vc, m, n, new float[] {
						r0 * Mth.sin(a0), r0 * Mth.cos(a0), z,
						r1 * Mth.sin(a1), r1 * Mth.cos(a1), z,
						r1 * Mth.sin(a1 + span), r1 * Mth.cos(a1 + span), z,
						r0 * Mth.sin(a0 + span), r0 * Mth.cos(a0 + span), z}, uv, r, g, b, 1, light, 0, 0, 1);
				// the blade's edge: a thin dark line on both faces
				float w0 = 0.035F / Math.max(0.25F, r0), w1 = 0.035F / Math.max(0.25F, r1);
				for(int side = 1; side >= -1; side -= 2)
				{
					float ze = 0.06F + side * 0.004F;
					quad(vc, m, n, new float[] {
							r0 * Mth.sin(a0), r0 * Mth.cos(a0), ze,
							r1 * Mth.sin(a1), r1 * Mth.cos(a1), ze,
							r1 * Mth.sin(a1 + w1), r1 * Mth.cos(a1 + w1), ze,
							r0 * Mth.sin(a0 + w0), r0 * Mth.cos(a0 + w0), ze}, uv, look.edgeR, look.edgeG, look.edgeB, 1, light, 0, 0, side);
				}
			}
		}
	}
}
