package io.github.stargatecommand.sginfinity.client;

import gcewing.sg.client.renderer.SGBaseTERenderer;
import net.minecraft.tileentity.TileEntity;

/**
 * Draws an Infinity gate with SGCraft's own gate renderer, so it turns, locks chevrons, opens and
 * closes exactly as SGCraft's gates do. For as long as it draws, SGCraft's gate textures are the
 * Infinity ones (see InfinityTextures).
 */
public class InfinityGateRenderer extends SGBaseTERenderer {

    @Override
    public void render(TileEntity te, double x, double y, double z, float partialTicks, int destroyStage, float alpha) {
        InfinityTextures.swapIn();
        try {
            super.render(te, x, y, z, partialTicks, destroyStage, alpha);
        } finally {
            InfinityTextures.swapOut();
        }
    }
}
