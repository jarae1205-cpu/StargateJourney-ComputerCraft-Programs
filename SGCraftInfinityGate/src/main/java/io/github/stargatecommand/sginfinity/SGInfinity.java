package io.github.stargatecommand.sginfinity;

import gcewing.sg.SGCraft;
import net.minecraft.block.Block;
import net.minecraft.item.Item;
import net.minecraft.item.ItemBlock;
import net.minecraft.util.ResourceLocation;
import net.minecraftforge.event.RegistryEvent;
import net.minecraftforge.fml.common.Mod;
import net.minecraftforge.fml.common.SidedProxy;
import net.minecraftforge.fml.common.event.FMLPreInitializationEvent;
import net.minecraftforge.fml.common.eventhandler.SubscribeEvent;
import net.minecraftforge.fml.common.registry.GameRegistry;

/**
 * Infinity Stargate for SGCraft: a stargate base whose gate is drawn as the gate of the animated
 * series Stargate Infinity. Build the ring around it from SGCraft's own Ring and Chevron Blocks;
 * everything else (addresses, dialing, the DHD, power, the iris, computers) is SGCraft's.
 */
@Mod(modid = SGInfinity.MOD_ID, name = SGInfinity.NAME, version = SGInfinity.VERSION,
        dependencies = "required-after:sgcraft@[2.3.0,)", acceptedMinecraftVersions = "[1.12.2]")
@Mod.EventBusSubscriber(modid = SGInfinity.MOD_ID)
public class SGInfinity {

    public static final String MOD_ID = "sginfinity";
    public static final String NAME = "Infinity Stargate for SGCraft";
    public static final String VERSION = "1.0.0";

    public static InfinityBaseBlock infinityBase;
    public static Item infinityBaseItem;

    @SidedProxy(clientSide = "io.github.stargatecommand.sginfinity.client.ClientProxy",
            serverSide = "io.github.stargatecommand.sginfinity.CommonProxy")
    public static CommonProxy proxy;

    @Mod.EventHandler
    public void preInit(FMLPreInitializationEvent event) {
        proxy.preInit();
    }

    @SubscribeEvent
    public static void registerBlocks(RegistryEvent.Register<Block> event) {
        infinityBase = new InfinityBaseBlock();
        infinityBase.setRegistryName(MOD_ID, "infinity_base");
        infinityBase.setTranslationKey(MOD_ID + ".infinity_base");
        event.getRegistry().register(infinityBase);
        GameRegistry.registerTileEntity(InfinityBaseTE.class, new ResourceLocation(MOD_ID, "infinity_base"));
    }

    @SubscribeEvent
    public static void registerItems(RegistryEvent.Register<Item> event) {
        infinityBaseItem = new ItemBlock(infinityBase).setRegistryName(infinityBase.getRegistryName());
        // next to SGCraft's own base, in its creative tab
        if (SGCraft.mod != null && SGCraft.mod.creativeTab != null) {
            infinityBase.setCreativeTab(SGCraft.mod.creativeTab);
            infinityBaseItem.setCreativeTab(SGCraft.mod.creativeTab);
        }
        event.getRegistry().register(infinityBaseItem);
    }
}
