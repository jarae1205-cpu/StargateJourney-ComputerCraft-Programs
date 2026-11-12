package io.github.stargatecommand.sgcaddon;

import java.util.function.Supplier;

import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.SlabBlock;
import net.minecraft.world.level.block.SoundType;
import net.minecraft.world.level.block.StairBlock;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraft.world.level.block.state.BlockBehaviour;
import net.minecraft.world.level.material.MapColor;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

/**
 * Stargate Command Addon: gate room blocks for Stargate Journey.
 */
@Mod(SGCAddon.MOD_ID)
public class SGCAddon
{
	public static final String MOD_ID = "sgcaddon";

	public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, MOD_ID);
	public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, MOD_ID);
	public static final DeferredRegister<BlockEntityType<?>> BLOCK_ENTITIES = DeferredRegister.create(ForgeRegistries.BLOCK_ENTITY_TYPES, MOD_ID);
	public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, MOD_ID);

	// lights up and sounds a klaxon while a gate nearby has an incoming wormhole
	public static final RegistryObject<Block> ALARM_LIGHT = block("alarm_light", () -> new AlarmLightBlock(
			BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_RED).strength(1.5F, 6.0F).sound(SoundType.GLASS)
					.lightLevel(state -> state.getValue(AlarmLightBlock.LIT) ? 15 : 0)));

	// redstone while the nearest gate's wormhole is open, comparator signal = chevrons locked
	public static final RegistryObject<Block> GATE_MONITOR = block("gate_monitor", () -> new GateMonitorBlock(
			BlockBehaviour.Properties.of().mapColor(MapColor.METAL).strength(3.0F, 6.0F).sound(SoundType.METAL)
					.lightLevel(state -> state.getValue(GateMonitorBlock.OPEN) ? 7 : 0).requiresCorrectToolForDrops()));

	// SGC gate room building blocks
	public static final RegistryObject<Block> GATE_RAMP = block("gate_ramp", () -> new Block(
			BlockBehaviour.Properties.of().mapColor(MapColor.METAL).strength(3.0F, 6.0F).sound(SoundType.METAL)
					.noOcclusion().requiresCorrectToolForDrops()));
	public static final RegistryObject<Block> GATE_RAMP_STAIRS = block("gate_ramp_stairs", () -> new StairBlock(
			() -> GATE_RAMP.get().defaultBlockState(), BlockBehaviour.Properties.copy(GATE_RAMP.get())));
	public static final RegistryObject<Block> GATE_RAMP_SLAB = block("gate_ramp_slab", () -> new SlabBlock(
			BlockBehaviour.Properties.copy(GATE_RAMP.get())));
	public static final RegistryObject<Block> SGC_WALL_PANEL = block("sgc_wall_panel", () -> new Block(
			BlockBehaviour.Properties.of().mapColor(MapColor.STONE).strength(2.0F, 8.0F).sound(SoundType.STONE).requiresCorrectToolForDrops()));
	public static final RegistryObject<Block> SGC_HAZARD_STRIPES = block("sgc_hazard_stripes", () -> new Block(
			BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_YELLOW).strength(2.0F, 8.0F).sound(SoundType.STONE).requiresCorrectToolForDrops()));
	public static final RegistryObject<Block> SGC_FLOOR_TILES = block("sgc_floor_tiles", () -> new Block(
			BlockBehaviour.Properties.of().mapColor(MapColor.COLOR_GRAY).strength(2.0F, 8.0F).sound(SoundType.STONE).requiresCorrectToolForDrops()));

	public static final RegistryObject<BlockEntityType<AlarmLightBlockEntity>> ALARM_LIGHT_ENTITY = BLOCK_ENTITIES.register("alarm_light",
			() -> BlockEntityType.Builder.of(AlarmLightBlockEntity::new, ALARM_LIGHT.get()).build(null));
	public static final RegistryObject<BlockEntityType<GateMonitorBlockEntity>> GATE_MONITOR_ENTITY = BLOCK_ENTITIES.register("gate_monitor",
			() -> BlockEntityType.Builder.of(GateMonitorBlockEntity::new, GATE_MONITOR.get()).build(null));

	public static final RegistryObject<CreativeModeTab> TAB = TABS.register("stargate_command", () -> CreativeModeTab.builder()
			.title(Component.translatable("itemGroup.sgcaddon"))
			.icon(() -> new ItemStack(ALARM_LIGHT.get()))
			.displayItems((parameters, output) -> ITEMS.getEntries().forEach(item -> output.accept(item.get())))
			.build());

	private static RegistryObject<Block> block(String name, Supplier<Block> supplier)
	{
		RegistryObject<Block> block = BLOCKS.register(name, supplier);
		ITEMS.register(name, () -> new BlockItem(block.get(), new Item.Properties()));
		return block;
	}

	public SGCAddon(FMLJavaModLoadingContext context)
	{
		IEventBus bus = context.getModEventBus();
		BLOCKS.register(bus);
		ITEMS.register(bus);
		BLOCK_ENTITIES.register(bus);
		TABS.register(bus);
	}
}
