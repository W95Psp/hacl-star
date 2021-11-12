/* MIT License
 *
 * Copyright (c) 2016-2020 INRIA, CMU and Microsoft Corporation
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */


#include "Hacl_Impl_Sparkle.h"

uint32_t Hacl_Impl_Sparkle_size_word = (uint32_t)4U;

uint32_t Hacl_Impl_Sparkle_vsize_rcon = (uint32_t)8U;

const
uint32_t
Hacl_Impl_Sparkle_rcon[8U] =
  {
    (uint32_t)0xB7E15162U, (uint32_t)0xBF715880U, (uint32_t)0x38B4DA56U, (uint32_t)0x324E7738U,
    (uint32_t)0xBB1185EBU, (uint32_t)0x4F7C7B57U, (uint32_t)0xCFBFA1C8U, (uint32_t)0xC2B3293DU
  };

typedef struct branch1_s
{
  uint32_t fst;
  uint32_t snd;
}
branch1;

#include <stdlib.h>
#include <stdio.h>
#include <immintrin.h>
#include <x86intrin.h>


void Hacl_Impl_Sparkle_l_step(uint32_t n, uint32_t *perm, uint32_t i, uint32_t *result)
{
  uint32_t xi = result[(uint32_t)2U * i];
  uint32_t yi = result[(uint32_t)2U * i + (uint32_t)1U];
  uint32_t p0i = perm[(uint32_t)2U * i];
  uint32_t p1i = perm[(uint32_t)2U * i + (uint32_t)1U];
  branch1 branchIUpd = { .fst = xi ^ p0i, .snd = yi ^ p1i };
  uint32_t x = branchIUpd.fst;
  uint32_t y = branchIUpd.snd;
  perm[(uint32_t)2U * i] = x;
  perm[(uint32_t)2U * i + (uint32_t)1U] = y;
}

void Hacl_Impl_Sparkle_arx_n_step(uint32_t n, uint32_t i, uint32_t *b)
{
  branch1 branchI = { .fst = b[(uint32_t)2U * i], .snd = b[(uint32_t)2U * i + (uint32_t)1U] };
  uint32_t rcon_i = Hacl_Impl_Sparkle_rcon[i];
  uint32_t x0 = branchI.fst;
  uint32_t y0 = branchI.snd;
  uint32_t x1 = x0 + _rotr(y0, 31); 
  uint32_t y1 = y0 ^ _rotr(x1, 24);
  uint32_t x2 = x1 ^ rcon_i;
  uint32_t x3 = x2 + _rotr(y1, 17);
  uint32_t y2 = y1 ^ _rotr(x3, 17);
  uint32_t x4 = x3 ^ rcon_i;
  uint32_t x5 = x4 + y2;
  uint32_t y3 = y2 ^ _rotr(x5, 31);
  uint32_t x6 = x5 ^ rcon_i;
  uint32_t x7 = x6 + _rotr(y3, 24);
  uint32_t y4 = y3 ^ _rotr(x7, 16);
  uint32_t x8 = x7 ^ rcon_i;
  branch1 scrut = { .fst = x8, .snd = y4 };
  uint32_t x = scrut.fst;
  uint32_t y = scrut.snd;
  b[(uint32_t)2U * i] = x;
  b[(uint32_t)2U * i + (uint32_t)1U] = y;
}

typedef struct __Spec_SPARKLE2_branch1_Spec_SPARKLE2_branch1_Spec_SPARKLE2_branch1_s
{
  branch1 fst;
  branch1 snd;
  branch1 thd;
}
__Spec_SPARKLE2_branch1_Spec_SPARKLE2_branch1_Spec_SPARKLE2_branch1;

void Hacl_Impl_Sparkle_sparkle256(uint32_t steps, uint8_t *i, uint8_t *o)
{
  uint32_t temp[12U] = { 0U };
  {
    uint32_t *os = temp;
    uint8_t *bj = i + (uint32_t)0U * (uint32_t)4U;
    uint32_t u = load32_le(bj);
    uint32_t r = u;
    uint32_t x = r;
    os[0U] = x;
  }
  {
    uint32_t *os = temp;
    uint8_t *bj = i + (uint32_t)1U * (uint32_t)4U;
    uint32_t u = load32_le(bj);
    uint32_t r = u;
    uint32_t x = r;
    os[1U] = x;
  }
  {
    uint32_t *os = temp;
    uint8_t *bj = i + (uint32_t)2U * (uint32_t)4U;
    uint32_t u = load32_le(bj);
    uint32_t r = u;
    uint32_t x = r;
    os[2U] = x;
  }
  {
    uint32_t *os = temp;
    uint8_t *bj = i + (uint32_t)3U * (uint32_t)4U;
    uint32_t u = load32_le(bj);
    uint32_t r = u;
    uint32_t x = r;
    os[3U] = x;
  }
  {
    uint32_t *os = temp;
    uint8_t *bj = i + (uint32_t)4U * (uint32_t)4U;
    uint32_t u = load32_le(bj);
    uint32_t r = u;
    uint32_t x = r;
    os[4U] = x;
  }
  {
    uint32_t *os = temp;
    uint8_t *bj = i + (uint32_t)5U * (uint32_t)4U;
    uint32_t u = load32_le(bj);
    uint32_t r = u;
    uint32_t x = r;
    os[5U] = x;
  }
  {
    uint32_t *os = temp;
    uint8_t *bj = i + (uint32_t)6U * (uint32_t)4U;
    uint32_t u = load32_le(bj);
    uint32_t r = u;
    uint32_t x = r;
    os[6U] = x;
  }
  {
    uint32_t *os = temp;
    uint8_t *bj = i + (uint32_t)7U * (uint32_t)4U;
    uint32_t u = load32_le(bj);
    uint32_t r = u;
    uint32_t x = r;
    os[7U] = x;
  }
  for (uint32_t i1 = (uint32_t)0U; i1 < steps; i1++)
  {
    uint32_t x00 = temp[0U];
    uint32_t y00 = temp[1U];
    uint32_t x1 = temp[2U];
    uint32_t y1 = temp[3U];
    uint32_t i0 = i1 & (uint32_t)7U;
    uint32_t y010 = y00 ^ Hacl_Impl_Sparkle_rcon[i0];
    uint32_t y11 = y1 ^ i1;
    temp[0U] = x00;
    temp[1U] = y010;
    temp[2U] = x1;
    temp[3U] = y11;
    {
      Hacl_Impl_Sparkle_arx_n_step((uint32_t)4U, (uint32_t)0U, temp);
    }
    {
      Hacl_Impl_Sparkle_arx_n_step((uint32_t)4U, (uint32_t)1U, temp);
    }
    {
      Hacl_Impl_Sparkle_arx_n_step((uint32_t)4U, (uint32_t)2U, temp);
    }
    {
      Hacl_Impl_Sparkle_arx_n_step((uint32_t)4U, (uint32_t)3U, temp);
    }
    uint32_t tx = (uint32_t)0U;
    uint32_t ty = (uint32_t)0U;
    {
      uint32_t xi = temp[(uint32_t)2U * (uint32_t)0U];
      uint32_t yi = temp[(uint32_t)2U * (uint32_t)0U + (uint32_t)1U];
      uint32_t tx_0 = tx;
      uint32_t ty_0 = ty;
      tx = xi ^ tx_0;
      ty = yi ^ ty_0;
    }
    {
      uint32_t xi = temp[(uint32_t)2U * (uint32_t)1U];
      uint32_t yi = temp[(uint32_t)2U * (uint32_t)1U + (uint32_t)1U];
      uint32_t tx_0 = tx;
      uint32_t ty_0 = ty;
      tx = xi ^ tx_0;
      ty = yi ^ ty_0;
    }
    uint32_t uu____0 = tx;
    uint32_t
    ltx0 = (uu____0 << (uint32_t)16U | uu____0 >> (uint32_t)16U) ^ (uu____0 & (uint32_t)0xffffU);
    uint32_t uu____1 = ty;
    uint32_t
    lty0 = (uu____1 << (uint32_t)16U | uu____1 >> (uint32_t)16U) ^ (uu____1 & (uint32_t)0xffffU);
    branch1 scrut = { .fst = ltx0, .snd = lty0 };
    uint32_t ltx = scrut.fst;
    uint32_t lty = scrut.snd;
    uint32_t x0 = (uint32_t)0U;
    uint32_t y0 = (uint32_t)0U;
    x0 = temp[0U];
    y0 = temp[1U];
    {
      branch1
      branch_j_nb =
        {
          .fst = temp[(uint32_t)2U * ((uint32_t)0U + (uint32_t)1U + (uint32_t)2U)],
          .snd = temp[(uint32_t)2U * ((uint32_t)0U + (uint32_t)1U + (uint32_t)2U) + (uint32_t)1U]
        };
      branch1
      branch_j =
        {
          .fst = temp[(uint32_t)2U * ((uint32_t)0U + (uint32_t)1U)],
          .snd = temp[(uint32_t)2U * ((uint32_t)0U + (uint32_t)1U) + (uint32_t)1U]
        };
      __Spec_SPARKLE2_branch1_Spec_SPARKLE2_branch1_Spec_SPARKLE2_branch1
      scrut0 = { .fst = branch_j_nb, .snd = branch_j, .thd = { .fst = lty, .snd = ltx } };
      uint32_t i2y = scrut0.thd.snd;
      uint32_t i2x = scrut0.thd.fst;
      uint32_t i1y = scrut0.snd.snd;
      uint32_t i1x = scrut0.snd.fst;
      uint32_t i0y = scrut0.fst.snd;
      uint32_t i0x = scrut0.fst.fst;
      uint32_t o0_x = i0x ^ (i1x ^ i2x);
      uint32_t o0_y = i0y ^ (i1y ^ i2y);
      branch1 b0 = { .fst = o0_x, .snd = o0_y };
      uint32_t x = b0.fst;
      uint32_t y2 = b0.snd;
      temp[(uint32_t)2U * (uint32_t)0U] = x;
      temp[(uint32_t)2U * (uint32_t)0U + (uint32_t)1U] = y2;
      uint32_t x2 = temp[(uint32_t)2U * ((uint32_t)0U + (uint32_t)1U)];
      uint32_t y = temp[(uint32_t)2U * ((uint32_t)0U + (uint32_t)1U) + (uint32_t)1U];
      temp[(uint32_t)2U * ((uint32_t)0U + (uint32_t)1U + (uint32_t)2U)] = x2;
      temp[(uint32_t)2U * ((uint32_t)0U + (uint32_t)1U + (uint32_t)2U) + (uint32_t)1U] = y;
    }
    uint32_t x01 = x0;
    uint32_t y01 = y0;
    uint32_t i0x = temp[4U];
    uint32_t i0y = temp[5U];
    uint32_t i1x = x01;
    uint32_t i1y = y01;
    uint32_t i2x = lty;
    uint32_t i2y = ltx;
    uint32_t o0_x = i0x ^ (i1x ^ i2x);
    uint32_t o0_y = i0y ^ (i1y ^ i2y);
    branch1 last0 = { .fst = o0_x, .snd = o0_y };
    uint32_t x = last0.fst;
    uint32_t y = last0.snd;
    temp[(uint32_t)2U * ((uint32_t)2U - (uint32_t)1U)] = x;
    temp[(uint32_t)2U * ((uint32_t)2U - (uint32_t)1U) + (uint32_t)1U] = y;
    temp[4U] = x01;
    temp[5U] = y01;
  }
  {
    store32_le(o + (uint32_t)0U * (uint32_t)4U, temp[0U]);
  }
  {
    store32_le(o + (uint32_t)1U * (uint32_t)4U, temp[1U]);
  }
  {
    store32_le(o + (uint32_t)2U * (uint32_t)4U, temp[2U]);
  }
  {
    store32_le(o + (uint32_t)3U * (uint32_t)4U, temp[3U]);
  }
  {
    store32_le(o + (uint32_t)4U * (uint32_t)4U, temp[4U]);
  }
  {
    store32_le(o + (uint32_t)5U * (uint32_t)4U, temp[5U]);
  }
  {
    store32_le(o + (uint32_t)6U * (uint32_t)4U, temp[6U]);
  }
  {
    store32_le(o + (uint32_t)7U * (uint32_t)4U, temp[7U]);
  }
}

