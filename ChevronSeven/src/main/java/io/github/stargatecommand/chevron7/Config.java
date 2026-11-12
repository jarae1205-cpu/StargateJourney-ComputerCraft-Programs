package io.github.stargatecommand.chevron7;

import net.minecraftforge.common.ForgeConfigSpec;

public final class Config
{
	private Config() {}

	public static final ForgeConfigSpec SPEC;
	public static final ForgeConfigSpec.IntValue MAX_OPEN_SECONDS;
	public static final ForgeConfigSpec.BooleanValue KAWOOSH_KILLS;
	public static final ForgeConfigSpec.BooleanValue INCOMING_CAN_CLOSE;
	public static final ForgeConfigSpec.BooleanValue GATE_FIELDS;

	static
	{
		ForgeConfigSpec.Builder builder = new ForgeConfigSpec.Builder();
		builder.push("stargate");
		MAX_OPEN_SECONDS = builder.comment("How long a wormhole stays open before it closes by itself, in seconds (38 minutes is 2280)")
				.defineInRange("max_open_seconds", 300, 10, 2280);
		KAWOOSH_KILLS = builder.comment("The unstable vortex of an opening wormhole destroys what stands in front of the gate")
				.define("kawoosh_kills", true);
		INCOMING_CAN_CLOSE = builder.comment("The receiving gate can close a wormhole too (normally only the dialing gate can)")
				.define("incoming_can_close", false);
		builder.pop();
		builder.push("world");
		GATE_FIELDS = builder.comment("Gate fields (five gates around a clearing) appear in plains, meadows and savannas")
				.define("gate_fields", true);
		builder.pop();
		SPEC = builder.build();
	}
}
