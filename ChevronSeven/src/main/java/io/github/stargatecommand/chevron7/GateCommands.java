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
 * /chevron7 list | address | dial | close | iris, for operators.
 */
public final class GateCommands
{
	private GateCommands() {}

	public static void register(RegisterCommandsEvent event)
	{
		CommandDispatcher<CommandSourceStack> dispatcher = event.getDispatcher();
		dispatcher.register(Commands.literal("chevron7").requires(source -> source.hasPermission(2))
				.then(Commands.literal("list").executes(GateCommands::list))
				.then(Commands.literal("address").then(Commands.argument("gate", BlockPosArgument.blockPos())
						.executes(context -> {
							StargateBlockEntity gate = gate(context);
							String text = GateAddress.format(gate.getAddress()) + " " + gate.getState().name().toLowerCase();
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
						.then(Commands.literal("close").executes(context -> iris(context, true))))));
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

	private static int iris(CommandContext<CommandSourceStack> context, boolean closed) throws CommandSyntaxException
	{
		StargateBlockEntity gate = gate(context);
		if(!gate.setIris(closed))
		{
			context.getSource().sendFailure(Component.translatable("message.chevron7.no_iris"));
			return 0;
		}
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
