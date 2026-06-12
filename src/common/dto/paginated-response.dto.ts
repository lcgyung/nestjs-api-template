import { ApiProperty } from '@nestjs/swagger';

export class PageMetaDto {
  @ApiProperty() page!: number;
  @ApiProperty() limit!: number;
  @ApiProperty() total!: number;
  @ApiProperty() totalPages!: number;
}

/**
 * 표준 목록 응답 형태 — `{ items, meta }`.
 * 생성자가 유일한 생성 경로다(`!` 필드 미할당을 막기 위해 plainToInstance 무인자 경로를 쓰지 않는다).
 * 제네릭 Swagger 스키마는 엔드포인트에서 @ApiOkResponse + getSchemaPath 로 합성한다(후속).
 */
export class PaginatedResponseDto<T> {
  items!: T[];

  @ApiProperty({ type: PageMetaDto }) meta!: PageMetaDto;

  constructor(items: T[], total: number, query: { page: number; limit: number }) {
    this.items = items;
    this.meta = {
      page: query.page,
      limit: query.limit,
      total,
      totalPages: Math.ceil(total / query.limit),
    };
  }
}
