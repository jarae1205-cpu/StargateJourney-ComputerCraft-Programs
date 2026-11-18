package io.github.stargatecommand.chevron7;

import com.mojang.serialization.Codec;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.world.level.WorldGenLevel;
import net.minecraft.world.level.levelgen.Heightmap;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.FeaturePlaceContext;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;

/**
 * Places a gate field during world generation, on flat dry ground.
 * The field is centred on the middle of the chunk, so it stays within the chunks
 * world generation may write to.
 */
public class GateFieldFeature extends Feature<NoneFeatureConfiguration>
{
	public static final int GATES = 5;

	public GateFieldFeature(Codec<NoneFeatureConfiguration> codec)
	{
		super(codec);
	}

	@Override
	public boolean place(FeaturePlaceContext<NoneFeatureConfiguration> context)
	{
		if(!Config.GATE_FIELDS.get())
			return false;
		WorldGenLevel level = context.level();
		BlockPos origin = context.origin();
		BlockPos center = new BlockPos((origin.getX() & ~15) + 8, origin.getY(), (origin.getZ() & ~15) + 8);
		Direction opens = Direction.from2DDataValue(context.random().nextInt(4));
		Heightmap.Types heightmap = Heightmap.Types.WORLD_SURFACE_WG;

		int[] range = GateField.groundRange(level, center, opens, GATES, heightmap);
		if(range[1] - range[0] > 4)
			return false;
		int y = GateField.groundY(level, center.getX(), center.getZ(), heightmap);
		if(!level.getFluidState(new BlockPos(center.getX(), y - 1, center.getZ())).isEmpty())
			return false;
		for(GateField.Site site : GateField.plan(center, opens, GATES))
		{
			int gy = GateField.groundY(level, site.core().getX(), site.core().getZ(), heightmap);
			if(!level.getFluidState(new BlockPos(site.core().getX(), gy - 1, site.core().getZ())).isEmpty())
				return false;
		}
		GateField.build(level, center, opens, GATES, heightmap);
		return true;
	}
}
