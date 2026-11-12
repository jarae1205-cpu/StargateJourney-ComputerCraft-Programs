package io.github.stargatecommand.chevron7;

import com.mojang.serialization.Codec;

import net.minecraft.core.BlockPos;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.FeaturePlaceContext;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;

/**
 * Runs in every chunk of the planets' biomes, and builds the planet's gate site in chunk 0, 0.
 */
public class PlanetGateFeature extends Feature<NoneFeatureConfiguration>
{
	public PlanetGateFeature(Codec<NoneFeatureConfiguration> codec)
	{
		super(codec);
	}

	@Override
	public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context)
	{
		BlockPos origin = context.origin();
		if((origin.getX() >> 4) != 0 || (origin.getZ() >> 4) != 0 || !Config.PLANET_GATES.get())
			return false;
		WorldGenLevel level = context.level();
		return PlanetGates.build(level, level.getSeed(), level.getLevel().dimension(), Heightmap.Types.WORLD_SURFACE_WG);
	}
}
