package io.github.stargatecommand.jsginfinity;

import net.minecraft.core.registries.Registries;
import net.minecraft.network.chat.Component;
import net.minecraft.world.item.BlockItem;
import net.minecraft.world.item.CreativeModeTab;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.block.Block;
import net.minecraft.world.level.block.entity.BlockEntityType;
import net.minecraftforge.eventbus.api.IEventBus;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.javafmlmod.FMLJavaModLoadingContext;
import net.minecraftforge.registries.DeferredRegister;
import net.minecraftforge.registries.ForgeRegistries;
import net.minecraftforge.registries.RegistryObject;

/**
 * The Infinity Stargate: a gate for Just Stargate Mod, built from its own base, ring and chevron
 * blocks in JSG's Milky Way pattern. Underneath it is JSG's Milky Way gate, so it dials, takes
 * a DHD, upgrades, an iris and computers just like one; only its blocks and its look differ.
 */
@Mod(JSGInfinity.MOD_ID)
public class JSGInfinity {
    public static final String MOD_ID = "jsginfinity";

    public static final DeferredRegister<Block> BLOCKS = DeferredRegister.create(ForgeRegistries.BLOCKS, MOD_ID);
    public static final DeferredRegister<Item> ITEMS = DeferredRegister.create(ForgeRegistries.ITEMS, MOD_ID);
    public static final DeferredRegister<BlockEntityType<?>> BLOCK_ENTITIES =
            DeferredRegister.create(ForgeRegistries.BLOCK_ENTITY_TYPES, MOD_ID);
    public static final DeferredRegister<CreativeModeTab> TABS = DeferredRegister.create(Registries.CREATIVE_MODE_TAB, MOD_ID);

    public static final RegistryObject<Block> BASE_BLOCK = BLOCKS.register("infinity_stargate_base_block", InfinityBlocks.Base::new);
    public static final RegistryObject<Block> RING_BLOCK = BLOCKS.register("infinity_stargate_ring_block", InfinityBlocks.Ring::new);
    public static final RegistryObject<Block> CHEVRON_BLOCK = BLOCKS.register("infinity_stargate_chevron_block", InfinityBlocks.Chevron::new);

    public static final RegistryObject<Item> BASE_ITEM = ITEMS.register("infinity_stargate_base_block",
            () -> new BlockItem(BASE_BLOCK.get(), new Item.Properties()));
    public static final RegistryObject<Item> RING_ITEM = ITEMS.register("infinity_stargate_ring_block",
            () -> new BlockItem(RING_BLOCK.get(), new Item.Properties()));
    public static final RegistryObject<Item> CHEVRON_ITEM = ITEMS.register("infinity_stargate_chevron_block",
            () -> new BlockItem(CHEVRON_BLOCK.get(), new Item.Properties()));

    @SuppressWarnings("DataFlowIssue") // the data fixer type is unused for mod block entities
    public static final RegistryObject<BlockEntityType<InfinityBaseBE>> BASE_BE = BLOCK_ENTITIES.register("infinity_stargate_base",
            () -> BlockEntityType.Builder.of(InfinityBaseBE::new, BASE_BLOCK.get()).build(null));
    @SuppressWarnings("DataFlowIssue")
    public static final RegistryObject<BlockEntityType<InfinityMemberBE>> MEMBER_BE = BLOCK_ENTITIES.register("infinity_stargate_member",
            () -> BlockEntityType.Builder.of(InfinityMemberBE::new, RING_BLOCK.get(), CHEVRON_BLOCK.get()).build(null));

    public static final RegistryObject<CreativeModeTab> TAB = TABS.register("infinity_stargate", () -> CreativeModeTab.builder()
            .title(Component.translatable("itemGroup.jsginfinity"))
            .icon(() -> new ItemStack(BASE_ITEM.get()))
            .displayItems((params, out) -> {
                out.accept(BASE_ITEM.get());
                out.accept(RING_ITEM.get());
                out.accept(CHEVRON_ITEM.get());
            })
            .build());

    public JSGInfinity() {
        IEventBus bus = FMLJavaModLoadingContext.get().getModEventBus();
        BLOCKS.register(bus);
        ITEMS.register(bus);
        BLOCK_ENTITIES.register(bus);
        TABS.register(bus);
    }
}
