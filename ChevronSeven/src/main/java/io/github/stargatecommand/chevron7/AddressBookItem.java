package io.github.stargatecommand.chevron7;

import java.util.List;
import java.util.function.Consumer;

import net.minecraft.ChatFormatting;
import net.minecraft.network.chat.Component;
import net.minecraft.server.MinecraftServer;
import net.minecraft.server.level.ServerLevel;
import net.minecraft.world.InteractionHand;
import net.minecraft.world.InteractionResultHolder;
import net.minecraft.world.entity.player.Player;
import net.minecraft.world.item.Item;
import net.minecraft.world.item.ItemStack;
import net.minecraft.world.level.Level;

/**
 * The Gate Address Book: lists the address of every planet's gate.
 */
public class AddressBookItem extends Item
{
	public AddressBookItem(Properties properties)
	{
		super(properties);
	}

	@Override
	public InteractionResultHolder<ItemStack> use(Level level, Player player, InteractionHand hand)
	{
		if(!level.isClientSide() && level.getServer() != null)
			describePlanets(level.getServer(), line -> player.sendSystemMessage(line));
		return InteractionResultHolder.sidedSuccess(player.getItemInHand(hand), level.isClientSide());
	}

	public static void describePlanets(MinecraftServer server, Consumer<Component> out)
	{
		List<ServerLevel> planets = PlanetGates.planets(server);
		if(planets.isEmpty())
		{
			out.accept(Component.translatable("message.chevron7.no_planets").withStyle(ChatFormatting.GRAY));
			return;
		}
		long seed = server.getWorldData().worldGenOptions().seed();
		out.accept(Component.translatable("message.chevron7.planets").withStyle(ChatFormatting.GOLD));
		for(ServerLevel planet : planets)
		{
			String address = GateAddress.format(PlanetGates.addressFor(seed, planet.dimension()));
			out.accept(Component.literal(PlanetGates.displayName(planet.dimension()) + "  ").withStyle(ChatFormatting.WHITE)
					.append(Component.literal(address).withStyle(ChatFormatting.AQUA)));
		}
		out.accept(Component.translatable("message.chevron7.planets_hint").withStyle(ChatFormatting.GRAY));
	}
}
