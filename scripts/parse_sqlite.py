#!/usr/bin/env python3
"""
SQLite数据库解析脚本
用于解析包含 ZCURRENT, ZDATE, ZGOAL 等字段的表数据
支持排序功能
"""

import sqlite3
import sys
import os
import re
from datetime import datetime


def list_tables(conn):
    """列出数据库中的所有表"""
    cursor = conn.cursor()
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
    tables = cursor.fetchall()
    return [t[0] for t in tables]


def get_table_schema(conn, table_name):
    """获取表的字段结构"""
    cursor = conn.cursor()
    cursor.execute(f"PRAGMA table_info({table_name});")
    columns = cursor.fetchall()
    return columns


def parse_date(timestamp):
    """
    解析日期时间戳
    从图片看，ZDATE 字段值如 795888740.980... 可能是:
    - CoreData 的 NSDate (自2001年1月1日以来的秒数)
    - Unix 时间戳 (自1970年1月1日以来的秒数)
    """
    try:
        # 尝试作为 CoreData 日期解析 (2001-01-01 基准)
        coredata_epoch = datetime(2001, 1, 1)
        coredata_date = coredata_epoch.timestamp() + float(timestamp)
        return datetime.fromtimestamp(coredata_date).strftime('%Y-%m-%d %H:%M:%S')
    except:
        try:
            # 尝试作为 Unix 时间戳解析
            return datetime.fromtimestamp(float(timestamp)).strftime('%Y-%m-%d %H:%M:%S')
        except:
            return str(timestamp)


def parse_sort_option(sort_str):
    """
    解析排序选项
    格式: 字段名:asc 或 字段名:desc
    示例: ZDATE:desc, ZCURRENT:asc
    """
    if not sort_str:
        return None, None
    
    # 支持格式: "ZDATE:desc" 或 "ZDATE" (默认asc)
    match = re.match(r'^(\w+)(?::(asc|desc))?$', sort_str, re.IGNORECASE)
    if match:
        column = match.group(1)
        order = match.group(2) or 'asc'
        return column, order.upper()
    return None, None


def query_table(conn, table_name, limit=None, sort_column=None, sort_order='ASC'):
    """查询表数据，支持排序"""
    cursor = conn.cursor()
    
    # 获取列名
    columns_info = get_table_schema(conn, table_name)
    column_names = [col[1] for col in columns_info]
    
    # 构建查询语句
    query = f"SELECT * FROM {table_name}"
    
    # 添加排序
    if sort_column and sort_column in column_names:
        query += f" ORDER BY {sort_column} {sort_order}"
    
    if limit:
        query += f" LIMIT {limit}"
    query += ";"
    
    cursor.execute(query)
    rows = cursor.fetchall()
    
    return column_names, rows


def display_data(column_names, rows, parse_dates=True, sort_column=None, sort_order=None):
    """格式化显示数据"""
    if not rows:
        print("表中无数据")
        return
    
    # 显示排序信息
    if sort_column:
        print(f"[排序: {sort_column} {sort_order}]\n")
    
    # 计算每列的最大宽度
    col_widths = []
    for i, col_name in enumerate(column_names):
        max_width = len(str(col_name))
        for row in rows:
            val = str(row[i]) if row[i] is not None else "NULL"
            max_width = max(max_width, len(val))
        col_widths.append(max_width + 2)
    
    # 打印表头
    header = " | ".join(
        f"{col_name:^{width}}" for col_name, width in zip(column_names, col_widths)
    )
    print(header)
    print("-" * len(header))
    
    # 打印数据行
    for row in rows:
        formatted_values = []
        for i, val in enumerate(row):
            col_name = column_names[i].upper()
            
            # 特殊处理 ZDATE 字段
            if parse_dates and 'DATE' in col_name and val is not None:
                try:
                    val = parse_date(val)
                except:
                    val = str(val) if val is not None else "NULL"
            else:
                val = str(val) if val is not None else "NULL"
            
            formatted_values.append(f"{val:^{col_widths[i]}}")
        
        print(" | ".join(formatted_values))
    
    print(f"\n共 {len(rows)} 条记录")


def export_to_csv(conn, table_name, output_file, sort_column=None, sort_order='ASC'):
    """导出数据到CSV文件，支持排序"""
    import csv
    
    column_names, rows = query_table(conn, table_name, sort_column=sort_column, sort_order=sort_order)
    
    with open(output_file, 'w', newline='', encoding='utf-8') as f:
        writer = csv.writer(f)
        writer.writerow(column_names)
        writer.writerows(rows)
    
    sort_info = f" (按 {sort_column} {sort_order})" if sort_column else ""
    print(f"数据已导出到: {output_file}{sort_info}")


def main():
    if len(sys.argv) < 2:
        print("用法: python parse_sqlite.py <db文件路径> [表名] [选项]")
        print("\n选项:")
        print("  --list                    列出所有表")
        print("  --schema                  显示表结构")
        print("  --export <文件>           导出到CSV文件")
        print("  --no-parse-date           不解析日期字段")
        print("  --sort <字段:顺序>        按字段排序 (顺序: asc/desc, 默认asc)")
        print("  --limit <数量>            限制返回记录数")
        print("\n排序示例:")
        print("  python parse_sqlite.py data.db ZTABLE --sort ZDATE:desc")
        print("  python parse_sqlite.py data.db ZTABLE --sort ZCURRENT:asc")
        print("  python parse_sqlite.py data.db ZTABLE --sort ZGOAL --limit 10")
        print("\n其他示例:")
        print("  python parse_sqlite.py data.db")
        print("  python parse_sqlite.py data.db --list")
        print("  python parse_sqlite.py data.db ZTABLE --schema")
        print("  python parse_sqlite.py data.db ZTABLE --export output.csv --sort ZDATE:desc")
        sys.exit(1)
    
    db_path = sys.argv[1]
    
    if not os.path.exists(db_path):
        print(f"错误: 文件不存在: {db_path}")
        sys.exit(1)
    
    try:
        conn = sqlite3.connect(db_path)
        
        # 只列出表
        if len(sys.argv) == 3 and sys.argv[2] == '--list':
            tables = list_tables(conn)
            print(f"数据库中的表 ({len(tables)} 个):")
            for table in tables:
                print(f"  - {table}")
            return
        
        # 获取表名
        table_name = None
        if len(sys.argv) >= 3 and not sys.argv[2].startswith('--'):
            table_name = sys.argv[2]
        else:
            tables = list_tables(conn)
            if len(tables) == 1:
                table_name = tables[0]
                print(f"自动选择唯一表: {table_name}")
            elif len(tables) > 1:
                print("数据库中有多个表，请指定表名:")
                for i, table in enumerate(tables, 1):
                    print(f"  {i}. {table}")
                print(f"\n用法: python parse_sqlite.py {db_path} <表名>")
                return
            else:
                print("数据库中没有表")
                return
        
        # 解析参数
        parse_dates = '--no-parse-date' not in sys.argv
        
        # 解析排序选项
        sort_column = None
        sort_order = 'ASC'
        if '--sort' in sys.argv:
            sort_idx = sys.argv.index('--sort')
            if sort_idx + 1 < len(sys.argv) and not sys.argv[sort_idx + 1].startswith('--'):
                sort_str = sys.argv[sort_idx + 1]
                sort_column, sort_order = parse_sort_option(sort_str)
                if sort_column:
                    # 验证字段是否存在
                    columns_info = get_table_schema(conn, table_name)
                    column_names = [col[1] for col in columns_info]
                    if sort_column not in column_names:
                        print(f"警告: 字段 '{sort_column}' 不存在，可用字段: {', '.join(column_names)}")
                        sort_column = None
                        sort_order = 'ASC'
        
        # 解析限制数量
        limit = None
        if '--limit' in sys.argv:
            limit_idx = sys.argv.index('--limit')
            if limit_idx + 1 < len(sys.argv) and not sys.argv[limit_idx + 1].startswith('--'):
                try:
                    limit = int(sys.argv[limit_idx + 1])
                except ValueError:
                    print(f"警告: --limit 需要数字参数")
        
        # 显示表结构
        if '--schema' in sys.argv:
            print(f"表 '{table_name}' 的结构:")
            columns = get_table_schema(conn, table_name)
            print(f"{'列名':<20} {'类型':<15} {'非空':<6} {'默认值':<15}")
            print("-" * 60)
            for col in columns:
                cid, name, ctype, notnull, dflt_value, pk = col
                print(f"{name:<20} {ctype or 'TEXT':<15} {notnull:<6} {str(dflt_value):<15}")
            return
        
        # 导出到CSV
        if '--export' in sys.argv:
            export_idx = sys.argv.index('--export')
            if export_idx + 1 < len(sys.argv) and not sys.argv[export_idx + 1].startswith('--'):
                output_file = sys.argv[export_idx + 1]
                export_to_csv(conn, table_name, output_file, sort_column=sort_column, sort_order=sort_order)
                return
        
        # 显示数据
        column_names, rows = query_table(conn, table_name, limit=limit, sort_column=sort_column, sort_order=sort_order)
        
        print(f"\n表: {table_name}")
        print(f"字段: {', '.join(column_names)}\n")
        
        display_data(column_names, rows, parse_dates=parse_dates, sort_column=sort_column, sort_order=sort_order)
        
        conn.close()
        
    except sqlite3.Error as e:
        print(f"SQLite 错误: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)


if __name__ == '__main__':
    main()
