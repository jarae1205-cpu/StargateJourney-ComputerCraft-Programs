package io.github.stargatecommand.chevron7;

import java.util.function.Supplier;

import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.resources.ResourceKey;
import net.minecraft.resources.ResourceLocation;
import net.minecraft.world.damagesource.DamageType;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.item.Rarity;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.minecraft.world.level.levelgen.feature.Feature;
import net.minecraft.world.level.levelgen.feature.configurations.NoneFeatureConfiguration;
import net.minecraft.world.level.material.PushReaction;
import net.minecraftforge.common.MinecraftForge;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.ModList;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.config.ModConfig;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

/**
 * Chevron Seven: a stargate mod built from scratch.
 */
@Mod(Chevron7.MOD_ID)
public class Chevron7
{
	public static final String MOD_ID = "chevron7";

	public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, MOD_ID);
	public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, MOD_ID);
	public static final DeferredRegister<BlockEntityType<?>> BLOCK_ENTITIES = DeferredRegister.create(ForgeRegistries.BLOCK_ENTITY_TYPES, MOD_ID);
	public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, MOD_ID);
	public static final DeferredRegister<Feature<?>> FEATURES = DeferredRegister.create(ForgeRegistries.FEATURES, MOD_ID);

	public static final RegistryObject<GateFieldFeature> GATE_FIELD = FEATURES.register("gate_field",
			() -> new GateFieldFeature(NoneFeatureConfiguration.CODEC));
	public static final RegistryObject<PlanetGateFeature> PLANET_GATE = FEATURES.register("planet_gate",
			() -> new PlanetGateFeature(NoneFeatureConfiguration.CODEC));

	public static final ResourceKey<DamageType> KAWOOSH = ResourceKey.create(Registries.DAMAGE_TYPE, id("kawoosh"));

	private static BlockBehaviour.Properties gateProperties()
	{
		return BlockBehaviour.Properties.of().mapColor(MapColor.STONE).strength(8.0F, 1200.0F).sound(SoundType.NETHERITE_BLOCK)
				.noOcclusion().requiresCorrectToolForDrops().pushReaction(PushReaction.BLOCK);
	}

	/** The bottom middle block of the ring: owns the gate and draws all of it. */
	public static final RegistryObject<StargateBlock> STARGATE = BLOCKS.register("stargate",
			() -> new StargateBlock(gateProperties().lightLevel(state -> state.getValue(StargateBlock.LIT) ? 12 : 0)));
	/** The other 23 blocks of the ring, invisible: they give the ring its collision. */
	public static final RegistryObject<GateFrameBlock> GATE_FRAME = BLOCKS.register("gate_frame",
			() -> new GateFrameBlock(gateProperties().noLootTable().lightLevel(state -> state.getValue(GateFrameBlock.LIT) ? 12 : 0)));
	public static final RegistryObject<DHDBlock> DHD = BLOCKS.register("dhd",
			() -> new DHDBlock(BlockBehaviour.Properties.of().mapColor(MapColor.TERRACOTTA_BROWN).strength(4.0F, 1200.0F)
					.sound(SoundType.STONE).noOcclusion().requiresCorrectToolForDrops().lightLevel(state -> 4)));

	public static final RegistryObject<Item> STARGATE_ITEM = ITEMS.register("stargate",
			() -> new BlockItem(STARGATE.get(), new Item.Properties().stacksTo(1).rarity(Rarity.RARE)));
	public static final RegistryObject<Item> DHD_ITEM = ITEMS.register("dhd",
			() -> new BlockItem(DHD.get(), new Item.Properties().stacksTo(1)));
	public static final RegistryObject<Item> IRIS = ITEMS.register("iris",
			() -> new IrisItem(new Item.Properties().stacksTo(1)));
	public static final RegistryObject<Item> ADDRESS_BOOK = ITEMS.register("address_book",
			() -> new AddressBookItem(new Item.Properties().stacksTo(1)));

	public static final RegistryObject<BlockEntityType<StargateBlockEntity>> STARGATE_ENTITY = BLOCK_ENTITIES.register("stargate",
			() -> BlockEntityType.Builder.of(StargateBlockEntity::new, STARGATE.get()).build(null));

	public static final RegistryObject<CreativeModeTab> TAB = TABS.register("chevron7", () -> CreativeModeTab.builder()
			.title(Component.translatable("itemGroup.chevron7"))
			.icon(() -> new ItemStack(STARGATE_ITEM.get()))
			.displayItems((parameters, output) -> ITEMS.getEntries().forEach(item -> output.accept(item.get())))
			.build());

	public Chevron7(FMLJavaModLoadingContext context)
	{
		IEventBus bus = context.getModEventBus();
		BLOCKS.register(bus);
		ITEMS.register(bus);
		BLOCK_ENTITIES.register(bus);
		TABS.register(bus);
		FEATURES.register(bus);
		context.registerConfig(ModConfig.Type.COMMON, Config.SPEC);
		Net.register();
		MinecraftForge.EVENT_BUS.addListener(GateCommands::register);
		if(ModList.get().isLoaded("computercraft"))
			runSafely(() -> io.github.stargatecommand.chevron7.compat.CCIntegration::init);
	}

	// keeps the CC: Tweaked classes from loading unless the mod is there
	private static void runSafely(Supplier<Runnable> task)
	{
		task.get().run();
	}

	public static ResourceLocation id(String path)
	{
		return new ResourceLocation(MOD_ID, path);
	}
}
