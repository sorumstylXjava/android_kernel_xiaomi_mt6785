/*
 * Copyright (C) 2019 MediaTek Inc.
 * Copyright (C) 2021 XiaoMi, Inc.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 2 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 */

#ifdef pr_fmt
#undef pr_fmt
#endif
#define pr_fmt(fmt) KBUILD_MODNAME ": " fmt


#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/printk.h>
#include <linux/types.h>
#include <linux/kobject.h>

#include "mt-plat/mtk_thermal_monitor.h"
#include <tscpu_settings.h>
#include "mtk_gpufreq.h"


#define mtk_cooler_gpu_dprintk(fmt, args...)	\
	pr_notice("thermal/cooler/gpu " fmt, ##args)

static struct thermal_cooling_device
*cl_gpu_dev = { 0 };
static unsigned int g_cl_id;
static unsigned int g_gpu_level;

static int mtk_cl_gpu_get_max_state
(struct thermal_cooling_device *cdev, unsigned long *state)
{
	*state = Num_of_GPU_OPP - gpu_max_opp - 1;
	return 0;
}

	static int mtk_cl_gpu_get_cur_state
(struct thermal_cooling_device *cdev, unsigned long *state)
{
	*state = g_gpu_level;
	return 0;
}

static int mtk_cl_gpu_set_cur_state
(struct thermal_cooling_device *cdev, unsigned long state)
{
	/* GhostKernel: Force GPU thermal protect level to 0 (unrestricted maximum GPU frequency) */
	g_gpu_level = 0;
	mt_gpufreq_thermal_protect(0);
	return 0;
}

#if 0 
static int mtk_cl_gpu_get_available
(struct thermal_cooling_device *cdev, char *available)
{
	int i  = 0, len = 0;

	if (mtk_gpu_power != NULL) {
		for (i = 0; i < Num_of_GPU_OPP - gpu_max_opp; i++) {
			len += snprintf(available+len, 256, "%d %u %u\n", i, mtk_gpu_power[i + gpu_max_opp].gpufreq_khz, mtk_gpu_power[i+gpu_max_opp].gpufreq_power);
			mtk_cooler_gpu_dprintk("len=%d\n", len);
			mtk_cooler_gpu_dprintk("%u %u\n", mtk_gpu_power[i + gpu_max_opp].gpufreq_khz, mtk_gpu_power[i + gpu_max_opp].gpufreq_power);
		}
	} else
		mtk_cooler_gpu_dprintk("%s: not gpu_power table\n", __func__);

	return 0;
}
#endif

/* bind fan callbacks to fan device */
static struct thermal_cooling_device_ops mtk_cl_gpu_ops = {
	.get_max_state = mtk_cl_gpu_get_max_state,
	.get_cur_state = mtk_cl_gpu_get_cur_state,
	.set_cur_state = mtk_cl_gpu_set_cur_state,
//.get_available = mtk_cl_gpu_get_available,
};

static int mtk_cooler_gpu_register_ltf(void)
{
	mtk_cooler_gpu_dprintk("%s\n", __func__);

	g_cl_id = 0;
	cl_gpu_dev = mtk_thermal_cooling_device_register
		("mtk-cl-gpu", (void *)&g_cl_id,
		 &mtk_cl_gpu_ops);

	return 0;
}

static void mtk_cooler_gpu_unregister_ltf(void)
{
	mtk_cooler_gpu_dprintk("%s\n", __func__);

	if (cl_gpu_dev) {
		mtk_thermal_cooling_device_unregister(cl_gpu_dev);
		cl_gpu_dev = NULL;
	}
}

static int __init mtk_cooler_gpu_init(void)
{
	int err = 0;

	err = mtk_cooler_gpu_register_ltf();
	if (err)
		goto err_unreg;

	return 0;

err_unreg:
	mtk_cooler_gpu_unregister_ltf();
	return err;
}

static void __exit mtk_cooler_gpu_exit(void)
{
	mtk_cooler_gpu_unregister_ltf();
}
module_init(mtk_cooler_gpu_init);
module_exit(mtk_cooler_gpu_exit);
