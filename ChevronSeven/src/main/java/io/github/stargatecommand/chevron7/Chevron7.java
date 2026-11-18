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

	private static StargateBlock gate(GateStyle style)
	{
		return new StargateBlock(gateProperties().lightLevel(state -> state.getValue(StargateBlock.LIT) ? 12 : 0), style);
	}

	private static BlockBehaviour.Properties gateProperties()
	{
		return BlockBehaviour.Properties.of().mapColor(MapColor.STONE).strength(8.0F, 1200.0F).sound(SoundType.NETHERITE_BLOCK)
				.noOcclusion().requiresCorrectToolForDrops().pushReaction(PushReaction.BLOCK);
	}

	private static BlockBehaviour.Properties partProperties()
	{
		return BlockBehaviour.Properties.of().mapColor(MapColor.STONE).strength(5.0F, 1200.0F).sound(SoundType.NETHERITE_BLOCK)
				.requiresCorrectToolForDrops();
	}

	/** The bottom middle block of the ring: owns the gate and draws all of it. */
	public static final RegistryObject<StargateBlock> STARGATE = BLOCKS.register("stargate", () -> gate(GateStyle.CLASSIC));
	/** A gate in the style of SGCraft's Stargate Network: a ring of letters, nine chevrons, letter addresses. */
	public static final RegistryObject<StargateBlock> NETWORK_STARGATE = BLOCKS.register("network_stargate", () -> gate(GateStyle.NETWORK));
	/** An Ori supergate's base: the giant ring is drawn around it. Built with /chevron7 supergate. */
	public static final RegistryObject<SupergateBlock> SUPERGATE = BLOCKS.register("supergate",
			() -> new SupergateBlock(gateProperties().lightLevel(state -> state.getValue(StargateBlock.LIT) ? 12 : 0)));
	/** The other 23 blocks of the ring, invisible: they give the ring its collision. */
	public static final RegistryObject<GateFrameBlock> GATE_FRAME = BLOCKS.register("gate_frame",
			() -> new GateFrameBlock(gateProperties().noLootTable().lightLevel(state -> state.getValue(GateFrameBlock.LIT) ? 12 : 0)));
	// SGCraft style: build the ring from these around a base, and the blocks become a gate
	public static final RegistryObject<StargateBaseBlock> STARGATE_BASE = BLOCKS.register("stargate_base",
			() -> new StargateBaseBlock(partProperties()));
	public static final RegistryObject<GatePartBlock> RING_BLOCK = BLOCKS.register("stargate_ring_block",
			() -> new GatePartBlock(partProperties(), false));
	public static final RegistryObject<GatePartBlock> CHEVRON_BLOCK = BLOCKS.register("stargate_chevron_block",
			() -> new GatePartBlock(partProperties(), true));
	/** Put it against a gate, and a computer against it. */
	public static final RegistryObject<GateInterfaceBlock> GATE_INTERFACE = BLOCKS.register("gate_interface",
			() -> new GateInterfaceBlock(BlockBehaviour.Properties.of().mapColor(MapColor.METAL).strength(3.5F, 6.0F)
					.sound(SoundType.METAL).requiresCorrectToolForDrops()));
	public static final RegistryObject<DHDBlock> DHD = BLOCKS.register("dhd",
			() -> new DHDBlock(BlockBehaviour.Properties.of().mapColor(MapColor.TERRACOTTA_BROWN).strength(4.0F, 1200.0F)
					.sound(SoundType.STONE).noOcclusion().requiresCorrectToolForDrops().lightLevel(state -> 4)));

	/** Put next to a gate, it is an SGCraft-style computer interface for it. */
	public static final RegistryObject<SGInterfaceBlock> SG_INTERFACE = BLOCKS.register("sg_interface",
			() -> new SGInterfaceBlock(BlockBehaviour.Properties.of().mapColor(MapColor.METAL).strength(4.0F, 1200.0F)
					.sound(SoundType.METAL).requiresCorrectToolForDrops()));

	public static final RegistryObject<Item> STARGATE_ITEM = ITEMS.register("stargate",
			() -> new BlockItem(STARGATE.get(), new Item.Properties().stacksTo(1).rarity(Rarity.RARE)));
	public static final RegistryObject<Item> NETWORK_STARGATE_ITEM = ITEMS.register("network_stargate",
			() -> new BlockItem(NETWORK_STARGATE.get(), new Item.Properties().stacksTo(1).rarity(Rarity.RARE)));
	public static final RegistryObject<Item> SG_INTERFACE_ITEM = ITEMS.register("sg_interface",
			() -> new BlockItem(SG_INTERFACE.get(), new Item.Properties()));
	public static final RegistryObject<Item> STARGATE_BASE_ITEM = ITEMS.register("stargate_base",
			() -> new BlockItem(STARGATE_BASE.get(), new Item.Properties().stacksTo(1).rarity(Rarity.UNCOMMON)));
	public static final RegistryObject<Item> RING_BLOCK_ITEM = ITEMS.register("stargate_ring_block",
			() -> new BlockItem(RING_BLOCK.get(), new Item.Properties()));
	public static final RegistryObject<Item> CHEVRON_BLOCK_ITEM = ITEMS.register("stargate_chevron_block",
			() -> new BlockItem(CHEVRON_BLOCK.get(), new Item.Properties()));
	public static final RegistryObject<Item> GATE_INTERFACE_ITEM = ITEMS.register("gate_interface",
			() -> new BlockItem(GATE_INTERFACE.get(), new Item.Properties()));
	public static final RegistryObject<Item> DHD_ITEM = ITEMS.register("dhd",
			() -> new BlockItem(DHD.get(), new Item.Properties().stacksTo(1)));
	public static final RegistryObject<Item> IRIS = ITEMS.register("iris",
			() -> new IrisItem(new Item.Properties().stacksTo(1)));
	public static final RegistryObject<Item> ADDRESS_BOOK = ITEMS.register("address_book",
			() -> new AddressBookItem(new Item.Properties().stacksTo(1)));
	public static final RegistryObject<Item> LOOK_CRYSTAL = ITEMS.register("look_crystal",
			() -> new LookCrystalItem(new Item.Properties().stacksTo(1)));

	public static final RegistryObject<BlockEntityType<StargateBlockEntity>> STARGATE_ENTITY = BLOCK_ENTITIES.register("stargate",
			() -> BlockEntityType.Builder.of(StargateBlockEntity::new, STARGATE.get(), NETWORK_STARGATE.get(), SUPERGATE.get()).build(null));
	public static final RegistryObject<BlockEntityType<StargateBaseBlockEntity>> STARGATE_BASE_ENTITY = BLOCK_ENTITIES.register("stargate_base",
			() -> BlockEntityType.Builder.of(StargateBaseBlockEntity::new, STARGATE_BASE.get()).build(null));
	public static final RegistryObject<BlockEntityType<DHDBlockEntity>> DHD_ENTITY = BLOCK_ENTITIES.register("dhd",
			() -> BlockEntityType.Builder.of(DHDBlockEntity::new, DHD.get()).build(null));
	public static final RegistryObject<BlockEntityType<SGInterfaceBlockEntity>> SG_INTERFACE_ENTITY = BLOCK_ENTITIES.register("sg_interface",
			() -> BlockEntityType.Builder.of(SGInterfaceBlockEntity::new, SG_INTERFACE.get()).build(null));

	/** Laid out like SGCraft's tab: the gate and the blocks it is built from, then what goes with it. */
	public static final RegistryObject<CreativeModeTab> TAB = TABS.register("chevron7", () -> CreativeModeTab.builder()
			.title(Component.translatable("itemGroup.chevron7"))
			.icon(() -> new ItemStack(CHEVRON_BLOCK_ITEM.get()))
			.displayItems((parameters, output) -> {
				output.accept(STARGATE_ITEM.get());
				output.accept(NETWORK_STARGATE_ITEM.get());
				output.accept(STARGATE_BASE_ITEM.get());
				output.accept(RING_BLOCK_ITEM.get());
				output.accept(CHEVRON_BLOCK_ITEM.get());
				output.accept(DHD_ITEM.get());
				output.accept(GATE_INTERFACE_ITEM.get());
				output.accept(SG_INTERFACE_ITEM.get());
				output.accept(IRIS.get());
				output.accept(LOOK_CRYSTAL.get());
				output.accept(ADDRESS_BOOK.get());
			})
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
		// open wormholes force-load their gates' chunks; the gates let go themselves once closed
		net.minecraftforge.common.world.ForgeChunkManager.setForcedChunkLoadingCallback(MOD_ID, (level, tickets) -> {});
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
