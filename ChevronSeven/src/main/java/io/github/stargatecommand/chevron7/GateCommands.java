package io.github.stargatecommand.chevron7;

import com.mojang.brigadier.CommandDispatcher;
import com.mojang.brigadier.arguments.StringArgumentType;
import com.mojang.brigadier.context.CommandContext;
import com.mojang.brigadier.exceptions.CommandSyntaxException;

import net.minecraft.commands.CommandSourceStack;
import net.minecraft.commands.Commands;
import net.minecraft.commands.arguments.coordinates.BlockPosArgument;
import net.minecraft.core.BlockPos;
import net.minecraft.network.chat.Component;
import net.minecraft.world.level.block.state.BlockState;
import net.minecraftforge.event.RegisterCommandsEvent;

/**
 * /chevron7 list | address | dial | close | iris | field | look | platform | pedestal | gateroom, for operators.
 */
public final class GateCommands
{
	private GateCommands() {}

	public static void register(RegisterCommandsEvent event)
	{
		CommandDispatcher<CommandSourceStack> dispatcher = event.getDispatcher();
		dispatcher.register(Commands.literal("chevron7").requires(source -> source.hasPermission(2))
				.then(Commands.literal("list").executes(GateCommands::list))
				.then(Commands.literal("planets").executes(context -> {
					AddressBookItem.describePlanets(context.getSource().getServer(), line -> context.getSource().sendSuccess(() -> line, false));
					return 1;
				}))
				.then(Commands.literal("field").then(Commands.argument("center", BlockPosArgument.blockPos())
						.executes(context -> field(context, "north", 5))
						.then(Commands.argument("direction", StringArgumentType.word())
								.executes(context -> field(context, StringArgumentType.getString(context, "direction"), 5))
								.then(Commands.argument("gates", com.mojang.brigadier.arguments.IntegerArgumentType.integer(1, GateField.MAX_GATES))
										.executes(context -> field(context, StringArgumentType.getString(context, "direction"),
												com.mojang.brigadier.arguments.IntegerArgumentType.getInteger(context, "gates")))))))
				.then(Commands.literal("address").then(Commands.argument("gate", BlockPosArgument.blockPos())
						.executes(context -> {
							StargateBlockEntity gate = gate(context);
							String text = GateAddress.format(gate.getAddress()) + " " + gate.getState().name().toLowerCase()
									+ (gate.hasIris() ? (gate.isIrisClosing() ? ", iris closed" : ", iris open") : "");
							context.getSource().sendSuccess(() -> Component.literal(text), false);
							return 1;
						})))
				.then(Commands.literal("dial").then(Commands.argument("gate", BlockPosArgument.blockPos())
						.then(Commands.argument("address", StringArgumentType.greedyString()).executes(context -> {
							StargateBlockEntity gate = gate(context);
							int[] address = GateAddress.parse(StringArgumentType.getString(context, "address"));
							if(address == null)
							{
								context.getSource().sendFailure(Component.translatable("feedback.chevron7.invalid_address"));
								return 0;
							}
							int result = gate.dial(address);
							context.getSource().sendSuccess(() -> Component.translatable("message.chevron7.dialing", GateAddress.format(address),
									Component.translatable("feedback.chevron7." + gate.getFeedbackText())), true);
							return result > 0 ? 1 : 0;
						}))))
				.then(Commands.literal("close").then(Commands.argument("gate", BlockPosArgument.blockPos())
						.executes(context -> {
							StargateBlockEntity gate = gate(context);
							gate.disconnect(true);
							context.getSource().sendSuccess(() -> Component.translatable("feedback.chevron7." + gate.getFeedbackText()), true);
							return 1;
						})))
				.then(Commands.literal("iris").then(Commands.argument("gate", BlockPosArgument.blockPos())
						.then(Commands.literal("open").executes(context -> iris(context, false)))
						.then(Commands.literal("close").executes(context -> iris(context, true)))))
				.then(Commands.literal("looks").executes(context -> {
					StringBuilder names = new StringBuilder();
					for(GateLook look : GateLook.values())
						names.append(names.length() == 0 ? "" : ", ").append(look.id);
					context.getSource().sendSuccess(() -> Component.translatable("message.chevron7.looks", names.toString()), false);
					return GateLook.values().length;
				}))
				.then(Commands.literal("look").then(Commands.argument("gate", BlockPosArgument.blockPos())
						.then(Commands.argument("look", StringArgumentType.word()).suggests(GateCommands::suggestLooks)
								.executes(context -> {
									StargateBlockEntity gate = gate(context);
									GateLook look = look(context, StringArgumentType.getString(context, "look"));
									gate.setLook(look);
									context.getSource().sendSuccess(() -> Component.translatable("message.chevron7.look", look.displayName()), true);
									return 1;
								}))))
				.then(Commands.literal("platform").then(Commands.argument("pos", BlockPosArgument.blockPos())
						.executes(context -> platform(context, null, "sg1", "stone"))
						.then(Commands.argument("direction", StringArgumentType.word()).suggests(GateCommands::suggestDirections)
								.executes(context -> platform(context, StringArgumentType.getString(context, "direction"), "sg1", "stone"))
								.then(Commands.argument("look", StringArgumentType.word()).suggests(GateCommands::suggestLooks)
										.executes(context -> platform(context, StringArgumentType.getString(context, "direction"),
												StringArgumentType.getString(context, "look"), "stone"))
										.then(Commands.argument("style", StringArgumentType.word()).suggests(GateCommands::suggestStyles)
												.executes(context -> platform(context, StringArgumentType.getString(context, "direction"),
														StringArgumentType.getString(context, "look"), StringArgumentType.getString(context, "style"))))))))
				.then(Commands.literal("pedestal").then(Commands.argument("pos", BlockPosArgument.blockPos())
						.executes(context -> pedestal(context, null, "small"))
						.then(Commands.argument("direction", StringArgumentType.word()).suggests(GateCommands::suggestDirections)
								.executes(context -> pedestal(context, StringArgumentType.getString(context, "direction"), "small"))
								.then(Commands.argument("size", StringArgumentType.word())
										.suggests((context, builder) -> net.minecraft.commands.SharedSuggestionProvider.suggest(
												java.util.List.of("small", "large"), builder))
										.executes(context -> pedestal(context, StringArgumentType.getString(context, "direction"),
												StringArgumentType.getString(context, "size")))))))
				.then(Commands.literal("gateroom").then(Commands.argument("pos", BlockPosArgument.blockPos())
						.executes(context -> gateRoom(context, null))
						.then(Commands.argument("direction", StringArgumentType.word()).suggests(GateCommands::suggestDirections)
								.executes(context -> gateRoom(context, StringArgumentType.getString(context, "direction")))))));
	}

	private static int list(CommandContext<CommandSourceStack> context)
	{
		GateNetwork network = GateNetwork.get(context.getSource().getServer());
		context.getSource().sendSuccess(() -> Component.translatable("message.chevron7.list", network.all().size()), false);
		for(GateNetwork.Entry entry : network.all().values())
		{
			String line = GateAddress.format(entry.address()) + " " + entry.dimension().location() + " " + entry.pos().toShortString();
			context.getSource().sendSuccess(() -> Component.literal(line), false);
		}
		return network.all().size();
	}

	/** Builds a gate field: the gates stand on an arc in the given direction from the centre. */
	private static int field(CommandContext<CommandSourceStack> context, String direction, int gates) throws CommandSyntaxException
	{
		BlockPos center = BlockPosArgument.getLoadedBlockPos(context, "center");
		net.minecraft.core.Direction opens = net.minecraft.core.Direction.byName(direction.toLowerCase());
		if(opens == null || opens.getAxis().isVertical())
		{
			context.getSource().sendFailure(Component.translatable("message.chevron7.bad_direction"));
			return 0;
		}
		var built = GateField.build(context.getSource().getLevel(), center, opens, gates,
				net.minecraft.world.level.levelgen.Heightmap.Types.MOTION_BLOCKING_NO_LEAVES);
		context.getSource().sendSuccess(() -> Component.translatable("message.chevron7.field_built", built.size()), true);
		return built.size();
	}

	private static java.util.concurrent.CompletableFuture<com.mojang.brigadier.suggestion.Suggestions> suggestLooks(
			CommandContext<CommandSourceStack> context, com.mojang.brigadier.suggestion.SuggestionsBuilder builder)
	{
		return net.minecraft.commands.SharedSuggestionProvider.suggest(java.util.Arrays.stream(GateLook.values()).map(look -> look.id), builder);
	}

	private static java.util.concurrent.CompletableFuture<com.mojang.brigadier.suggestion.Suggestions> suggestStyles(
			CommandContext<CommandSourceStack> context, com.mojang.brigadier.suggestion.SuggestionsBuilder builder)
	{
		return net.minecraft.commands.SharedSuggestionProvider.suggest(
				java.util.Arrays.stream(GateBuildings.Style.values()).map(style -> style.name().toLowerCase(java.util.Locale.ROOT)), builder);
	}

	private static java.util.concurrent.CompletableFuture<com.mojang.brigadier.suggestion.Suggestions> suggestDirections(
			CommandContext<CommandSourceStack> context, com.mojang.brigadier.suggestion.SuggestionsBuilder builder)
	{
		return net.minecraft.commands.SharedSuggestionProvider.suggest(new String[] {"north", "east", "south", "west"}, builder);
	}

	private static GateLook look(CommandContext<CommandSourceStack> context, String name) throws CommandSyntaxException
	{
		GateLook look = GateLook.byId(name);
		if(look == null)
			throw new com.mojang.brigadier.exceptions.SimpleCommandExceptionType(Component.translatable("message.chevron7.bad_look", name)).create();
		return look;
	}

	/** The way the gate faces: as given, or towards whoever ran the command. */
	@javax.annotation.Nullable
	private static net.minecraft.core.Direction facing(CommandContext<CommandSourceStack> context, @javax.annotation.Nullable String name)
	{
		if(name == null)
			return net.minecraft.core.Direction.fromYRot(context.getSource().getRotation().y).getOpposite();
		net.minecraft.core.Direction direction = net.minecraft.core.Direction.byName(name.toLowerCase());
		if(direction == null || direction.getAxis().isVertical())
		{
			context.getSource().sendFailure(Component.translatable("message.chevron7.bad_direction"));
			return null;
		}
		return direction;
	}

	private static int platform(CommandContext<CommandSourceStack> context, @javax.annotation.Nullable String direction, String lookName,
			String styleName) throws CommandSyntaxException
	{
		BlockPos pos = BlockPosArgument.getLoadedBlockPos(context, "pos");
		net.minecraft.core.Direction facing = facing(context, direction);
		if(facing == null)
			return 0;
		GateLook look = look(context, lookName);
		GateBuildings.Style style = GateBuildings.Style.byName(styleName);
		if(style == null)
			throw new com.mojang.brigadier.exceptions.SimpleCommandExceptionType(Component.literal("Styles: stone, deepslate, sandstone, blackstone, cap")).create();
		GateBuildings.platform(context.getSource().getLevel(), pos, facing, look, style);
		context.getSource().sendSuccess(() -> Component.translatable("message.chevron7.platform_built"), true);
		return 1;
	}

	/** A Carter Addon Pack pedestal with no gate, for a gate of any mod to stand on. */
	private static int pedestal(CommandContext<CommandSourceStack> context, @javax.annotation.Nullable String direction, String size)
			throws CommandSyntaxException
	{
		BlockPos pos = BlockPosArgument.getLoadedBlockPos(context, "pos");
		net.minecraft.core.Direction facing = facing(context, direction);
		if(facing == null)
			return 0;
		int half;
		if(size.equalsIgnoreCase("small"))
			half = GateBuildings.PEDESTAL_SMALL;
		else if(size.equalsIgnoreCase("large"))
			half = GateBuildings.PEDESTAL_LARGE;
		else
			throw new com.mojang.brigadier.exceptions.SimpleCommandExceptionType(Component.translatable("message.chevron7.bad_size")).create();
		BlockPos base = GateBuildings.pedestal(context.getSource().getLevel(), pos, facing, half);
		context.getSource().sendSuccess(() -> Component.translatable("message.chevron7.pedestal_built",
				base.getX(), base.getY(), base.getZ(), facing.getName()), true);
		return 1;
	}

	private static int gateRoom(CommandContext<CommandSourceStack> context, @javax.annotation.Nullable String direction) throws CommandSyntaxException
	{
		BlockPos pos = BlockPosArgument.getLoadedBlockPos(context, "pos");
		net.minecraft.core.Direction facing = facing(context, direction);
		if(facing == null)
			return 0;
		GateBuildings.gateRoom(context.getSource().getLevel(), pos, facing);
		context.getSource().sendSuccess(() -> Component.translatable("message.chevron7.gate_room_built"), true);
		return 1;
	}

	private static int iris(CommandContext<CommandSourceStack> context, boolean closed) throws CommandSyntaxException
	{
		StargateBlockEntity gate = gate(context);
		if(!gate.setIris(closed))
		{
			context.getSource().sendFailure(Component.translatable("message.chevron7.no_iris"));
			return 0;
		}
		context.getSource().sendSuccess(() -> Component.translatable(closed ? "message.chevron7.iris_closing" : "message.chevron7.iris_opening"), true);
		return 1;
	}

	private static StargateBlockEntity gate(CommandContext<CommandSourceStack> context) throws CommandSyntaxException
	{
		BlockPos pos = BlockPosArgument.getLoadedBlockPos(context, "gate");
		BlockState state = context.getSource().getLevel().getBlockState(pos);
		if(state.is(Chevron7.GATE_FRAME.get()))
			pos = GateFrameBlock.core(pos, state);
		if(context.getSource().getLevel().getBlockEntity(pos) instanceof StargateBlockEntity gate)
			return gate;
		throw new com.mojang.brigadier.exceptions.SimpleCommandExceptionType(Component.translatable("message.chevron7.not_a_gate")).create();
	}
}
