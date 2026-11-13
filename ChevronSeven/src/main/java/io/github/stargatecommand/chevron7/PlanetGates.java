package io.github.stargatecommand.chevron7;

import java.util.ArrayList;
import java.util.List;

import javax.annotation.Nullable;

import net.minecraft.core.BlockPos;
import net.minecraft.core.Direction;
import net.minecraft.core.registries.Registries;
import net.minecraft.resources.ResourceKey;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.tags.TagKey;
import net.minecraft.util.RandomSource;
import net.minecraft.world.level.Level;
import net.minecraft.world.level.LevelAccessor;
import net.minecraft.world.level.biome.Biome;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.Blocks;
import net.minecraft.world.level.block.entity.BlockEntity;
import net.minecraft.world.level.chunk.LevelChunk;
import net.minecraft.world.level.levelgen.Heightmap;

/**
 * Planet gates: every dimension made of biomes in the #chevron7:has_planet_gate tag (the planets
 * of Ad Astra) gets a gate site near 0, 0. Each planet's gate has a fixed address worked out from
 * the world seed, so it can be dialed before anyone has been there: the first wormhole generates it.
 */
public final class PlanetGates
{
	private PlanetGates() {}

	public static final TagKey<Biome> HAS_PLANET_GATE = TagKey.create(Registries.BIOME, Chevron7.id("has_planet_gate"));

	/** The gate of a planet stands in the middle of chunk 0, 0, facing south, with the DHD in front. */
	public static final BlockPos SITE = new BlockPos(8, 0, 6);

	public static int[] addressFor(long seed, ResourceKey<Level> dimension)
	{
		long mix = seed ^ (dimension.location().toString().hashCode() * 0x9E3779B97F4A7C15L);
		return GateAddress.random(RandomSource.create(mix));
	}

	public static boolean isPlanet(ServerLevel level)
	{
		if(!Config.PLANET_GATES.get())
			return false;
		return level.getChunkSource().getGenerator().getBiomeSource().possibleBiomes().stream().anyMatch(biome -> biome.is(HAS_PLANET_GATE));
	}

	public static List<ServerLevel> planets(MinecraftServer server)
	{
		List<ServerLevel> planets = new ArrayList<>();
		for(ServerLevel level : server.getAllLevels())
			if(isPlanet(level))
				planets.add(level);
		return planets;
	}

	/** "ad_astra:mars" becomes "Mars". */
	public static String displayName(ResourceKey<Level> dimension)
	{
		String path = dimension.location().getPath().replace('_', ' ');
		return path.isEmpty() ? path : Character.toUpperCase(path.charAt(0)) + path.substring(1);
	}

	/**
	 * The gate of the planet with this address, generating its site if nobody has been there yet.
	 * Null if no planet has this address.
	 */
	@Nullable
	public static StargateBlockEntity siteFor(MinecraftServer server, int[] address)
	{
		long seed = server.getWorldData().worldGenOptions().seed();
		for(ServerLevel planet : planets(server))
		{
			if(!GateAddress.same(addressFor(seed, planet.dimension()), address))
				continue;
			LevelChunk chunk = planet.getChunk(0, 0); // generates it, with the site, if needed
			for(BlockEntity blockEntity : chunk.getBlockEntities().values())
			{
				if(blockEntity instanceof StargateBlockEntity gate && GateAddress.same(gate.getAddress(), address))
				{
					gate.ensureRegistered(planet);
					return gate;
				}
			}
		}
		return null;
	}

	/** Builds the site: a paved pad with the gate and a DHD, on the ground at chunk 0, 0. */
	public static boolean build(LevelAccessor level, long seed, ResourceKey<Level> dimension, Heightmap.Types heightmap)
	{
		int flags = Block.UPDATE_CLIENTS;
		int y = level.getHeight(heightmap, SITE.getX(), SITE.getZ());
		if(y <= level.getMinBuildHeight() + 1)
			return false;
		BlockPos core = new BlockPos(SITE.getX(), y, SITE.getZ());
		Direction facing = Direction.SOUTH;

		// the pad: 11 by 11, paved, with nothing above it
		for(int dx = -5; dx <= 5; dx++)
		{
			for(int dz = -3; dz <= 7; dz++)
			{
				BlockPos floor = core.offset(dx, -1, dz);
				boolean edge = Math.abs(dx) == 5 || dz == -3 || dz == 7;
				level.setBlock(floor, (edge ? Blocks.STONE_BRICKS : Blocks.POLISHED_ANDESITE).defaultBlockState(), flags);
				for(int below = 1; below <= 6 && level.getBlockState(floor.below(below)).canBeReplaced(); below++)
					level.setBlock(floor.below(below), Blocks.STONE.defaultBlockState(), flags);
				for(int up = 0; up < 9; up++)
					level.setBlock(floor.above(up + 1), Blocks.AIR.defaultBlockState(), flags);
			}
		}

		level.setBlock(core, Chevron7.STARGATE.get().defaultBlockState().setValue(StargateBlock.FACING, facing), flags);
		for(int part = 0; part < GateShape.FRAME.length; part++)
		{
			level.setBlock(GateShape.frameCell(core, facing, part), Chevron7.GATE_FRAME.get().defaultBlockState()
					.setValue(GateFrameBlock.FACING, facing).setValue(GateFrameBlock.PART, part), flags);
		}
		if(level.getBlockEntity(core) instanceof StargateBlockEntity gate)
			gate.presetAddress(addressFor(seed, dimension));
		GateField.placeStep(level, core, facing, Blocks.POLISHED_ANDESITE_STAIRS, flags);
		level.setBlock(core.relative(facing, 5), Chevron7.DHD.get().defaultBlockState().setValue(DHDBlock.FACING, facing), flags);
		return true;
	}
}
