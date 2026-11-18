package io.github.stargatecommand.chevron7;

import java.util.Locale;

import javax.annotation.Nullable;

import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceLocation;

/**
 * How a gate looks. Each look has its own ring, symbol track and event horizon textures
 * (made by tools/make_resources.py) and the colours below for the chevrons, glyphs and iris.
 * SG-1 is the original look.
 */
public enum GateLook
{
	//          chevron lit             housing  glyphs                 iris                   iris edges             horizon tint
	SG1("sg1", 1.00F, 0.58F, 0.16F, 0.62F, 0.17F, 0.16F, 0.15F, 0.66F, 0.68F, 0.71F, 0.30F, 0.31F, 0.34F, 0.72F, 0.86F, 1.00F),
	MOVIE("movie", 1.00F, 0.40F, 0.10F, 0.56F, 0.15F, 0.12F, 0.10F, 0.60F, 0.58F, 0.56F, 0.26F, 0.24F, 0.22F, 1, 1, 1),
	ORIGINS("origins", 0.92F, 0.62F, 0.24F, 0.70F, 0.24F, 0.17F, 0.10F, 0.66F, 0.58F, 0.46F, 0.32F, 0.25F, 0.16F, 1, 1, 1),
	CONTINUUM("continuum", 1.00F, 0.58F, 0.16F, 0.72F, 0.20F, 0.24F, 0.30F, 0.80F, 0.85F, 0.90F, 0.36F, 0.42F, 0.50F, 1, 1, 1),
	ARK("ark", 1.00F, 0.84F, 0.32F, 0.80F, 0.30F, 0.20F, 0.06F, 0.84F, 0.70F, 0.36F, 0.40F, 0.28F, 0.08F, 1, 1, 1),
	ATLANTIS("atlantis", 0.32F, 0.74F, 1.00F, 0.66F, 0.52F, 0.74F, 0.96F, 0.56F, 0.66F, 0.80F, 0.18F, 0.26F, 0.40F, 1, 1, 1),
	UNIVERSE("universe", 0.95F, 0.97F, 1.00F, 0.60F, 0.82F, 0.86F, 0.92F, 0.44F, 0.46F, 0.50F, 0.12F, 0.12F, 0.14F, 1, 1, 1),
	INFINITY("infinity", 1.00F, 0.56F, 0.10F, 0.22F, 0.10F, 0.10F, 0.14F, 0.80F, 0.88F, 0.97F, 0.06F, 0.06F, 0.10F, 1, 1, 1),
	ORI("ori", 0.70F, 0.85F, 1.00F, 0.50F, 0.40F, 0.42F, 0.48F, 0.30F, 0.30F, 0.34F, 0.08F, 0.08F, 0.10F, 1, 1, 1),
	TOLLAN("tollan", 0.45F, 1.00F, 0.52F, 0.70F, 0.14F, 0.24F, 0.18F, 0.66F, 0.76F, 0.70F, 0.20F, 0.30F, 0.24F, 1, 1, 1),
	GOAULD("goauld", 1.00F, 0.70F, 0.20F, 0.70F, 0.26F, 0.16F, 0.06F, 0.80F, 0.62F, 0.34F, 0.36F, 0.24F, 0.08F, 1, 1, 1),
	WRAITH("wraith", 0.86F, 0.36F, 1.00F, 0.56F, 0.70F, 0.52F, 0.86F, 0.44F, 0.38F, 0.52F, 0.16F, 0.10F, 0.22F, 1, 1, 1),
	CRIMSON("crimson", 1.00F, 0.24F, 0.18F, 0.56F, 0.22F, 0.08F, 0.08F, 0.52F, 0.36F, 0.36F, 0.22F, 0.10F, 0.10F, 1, 1, 1);

	public final String id;
	public final float chevronR, chevronG, chevronB;
	/** How light the chevron housings are (they use the ring's texture). */
	public final float housing;
	public final float glyphR, glyphG, glyphB;
	public final float irisR, irisG, irisB;
	public final float edgeR, edgeG, edgeB;
	public final float horizonR, horizonG, horizonB;

	GateLook(String id, float cr, float cg, float cb, float housing, float gr, float gg, float gb,
			float ir, float ig, float ib, float er, float eg, float eb, float hr, float hg, float hb)
	{
		this.id = id;
		chevronR = cr; chevronG = cg; chevronB = cb;
		this.housing = housing;
		glyphR = gr; glyphG = gg; glyphB = gb;
		irisR = ir; irisG = ig; irisB = ib;
		edgeR = er; edgeG = eg; edgeB = eb;
		horizonR = hr; horizonG = hg; horizonB = hb;
	}

	private String suffix()
	{
		return this == SG1 ? "" : "_" + id;
	}

	public ResourceLocation stoneTexture()
	{
		return Chevron7.id("textures/entity/gate_stone" + suffix() + ".png");
	}

	public ResourceLocation trackTexture()
	{
		return Chevron7.id("textures/entity/gate_track" + suffix() + ".png");
	}

	public ResourceLocation horizonTexture()
	{
		return Chevron7.id("textures/entity/event_horizon" + suffix() + ".png");
	}

	public Component displayName()
	{
		return Component.translatable("look.chevron7." + id);
	}

	public GateLook next(int step)
	{
		GateLook[] all = values();
		return all[Math.floorMod(ordinal() + step, all.length)];
	}

	@Nullable
	public static GateLook byId(String id)
	{
		String key = id.toLowerCase(Locale.ROOT).replace("'", "").replace("-", "").replace(" ", "");
		if(key.equals("sg1") || key.equals("milkyway") || key.equals("default"))
			return SG1;
		if(key.equals("arkoftruth"))
			return ARK;
		if(key.equals("pegasus") || key.equals("lantea"))
			return ATLANTIS;
		if(key.equals("destiny"))
			return UNIVERSE;
		for(GateLook look : values())
			if(look.id.equals(key))
				return look;
		return null;
	}
}
